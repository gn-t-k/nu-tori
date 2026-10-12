import Foundation
import HTTPTypes
import NuToriAPI
import OpenAPIRuntime
import Synchronization

/// 偽の同期サーバーの手前で、変更の取得の要求が届いた時刻（仮の時計で、始めてからの長さ）を控える
final class FakeSyncServerProbe: ClientTransport, Sendable {
    /// 変更の取得の要求が届いた回数
    let pullArrivals = Tally()

    /// 変更の取得の要求が届いた時刻。届いた順
    var pullTimes: [Duration] {
        state.withLock { $0.pullTimes }
    }

    /// 取得の要求をそのまま偽のサーバーに通す
    static func passing(_ scenario: FakeSyncServer.Scenario, clock: SteppingClock)
        -> FakeSyncServerProbe
    {
        FakeSyncServerProbe(scenario, clock: clock, pulls: .passing)
    }

    /// 取得の要求を `releasePulls()` まで止める。同期が動いているあいだの形を確かめるため
    static func holdingPulls(_ scenario: FakeSyncServer.Scenario, clock: SteppingClock)
        -> FakeSyncServerProbe
    {
        FakeSyncServerProbe(scenario, clock: clock, pulls: .held([]))
    }

    func releasePulls() {
        let held = state.withLock { state in
            defer { state.pulls = .passing }
            switch state.pulls {
            case .passing: return [CheckedContinuation<Void, Never>]()
            case .held(let held): return held
            }
        }
        for pull in held {
            pull.resume()
        }
    }

    @concurrent func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if request.path?.hasPrefix("/v1/sync/changes") == true {
            await withCheckedContinuation { pull in
                let passes = state.withLock { state in
                    state.pullTimes.append(clock.elapsed)
                    switch state.pulls {
                    case .passing:
                        return true
                    case .held(let held):
                        state.pulls = .held(held + [pull])
                        return false
                    }
                }
                pullArrivals.add()
                if passes {
                    pull.resume()
                }
            }
        }
        return try await server.send(
            request, body: body, baseURL: baseURL, operationID: operationID)
    }

    private enum Pulls {
        case passing
        case held([CheckedContinuation<Void, Never>])
    }

    private struct State {
        var pullTimes: [Duration] = []
        var pulls: Pulls
    }

    private let server: FakeSyncServer
    private let clock: SteppingClock
    private let state: Mutex<State>

    private init(_ scenario: FakeSyncServer.Scenario, clock: SteppingClock, pulls: Pulls) {
        server = FakeSyncServer(scenario)
        self.clock = clock
        state = Mutex(State(pulls: pulls))
    }
}
