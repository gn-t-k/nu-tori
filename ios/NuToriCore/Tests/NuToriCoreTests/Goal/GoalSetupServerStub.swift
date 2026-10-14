import Foundation
import HTTPTypes
import NuToriTestSupport
import Synchronization

/// 目標の設定の要求に、経路ごとに並べた答えを順に返す（最後の答えはくり返す）。トランスポートは `transport`
final class GoalSetupServerStub: Sendable {
    enum Answer: Sendable {
        case json(String)
        /// 断る応答
        case rejected(HTTPResponse.Status, code: String)
        /// つながらない
        case offline
        /// `gate` が開くまで待ってから答える。答えが届く順を入れ替えるため
        case held(Gate, json: String)
    }

    /// 開くまで待たせる。取り消されても待ち続ける（取り消しでは答えが早まらない）
    final class Gate: Sendable {
        func open() {
            let waiting = state.withLock { state in
                state.isOpen = true
                defer { state.waiting = [] }
                return state.waiting
            }
            for continuation in waiting {
                continuation.resume()
            }
        }

        func wait() async {
            await withCheckedContinuation { continuation in
                let isOpen = state.withLock { state in
                    if !state.isOpen {
                        state.waiting.append(continuation)
                    }
                    return state.isOpen
                }
                if isOpen {
                    continuation.resume()
                }
            }
        }

        private struct State {
            var isOpen = false
            var waiting: [CheckedContinuation<Void, Never>] = []
        }

        private let state = Mutex(State())
    }

    /// 鍵は経路の最後の部分（`preview`・`proposals`・`custom-target-weight`・`decisions`）
    init(_ answers: [String: [Answer]]) {
        let queue = Queue(answers)
        self.queue = queue
        transport = .goalSetup { endpoint, _ in try await queue.respond(endpoint) }
    }

    let transport: ClientTransportMock

    /// 経路ごとの答えを、この答えだけに替える
    func replace(_ endpoint: String, with answer: Answer) {
        queue.replace(endpoint, with: answer)
    }

    /// 送った本文。経路ごとに送った順
    func bodies(_ endpoint: String) -> [String] {
        transport.requests.filter { $0.request.path?.hasSuffix("/" + endpoint) == true }.compactMap(
            \.body)
    }

    private let queue: Queue
}

private final class Queue: Sendable {
    init(_ answers: [String: [GoalSetupServerStub.Answer]]) {
        state = Mutex(answers)
    }

    func replace(_ endpoint: String, with answer: GoalSetupServerStub.Answer) {
        state.withLock { $0[endpoint] = [answer] }
    }

    func respond(_ endpoint: String) async throws -> (status: HTTPResponse.Status, json: String?) {
        let answer: GoalSetupServerStub.Answer? = state.withLock { answers in
            guard let queue = answers[endpoint], let first = queue.first else { return nil }
            if queue.count > 1 {
                answers[endpoint] = Array(queue.dropFirst())
            }
            return first
        }
        switch answer {
        case nil:
            return (.notFound, nil)
        case .json(let json):
            return (.ok, json)
        case .rejected(let status, let code):
            return (status, #"{"code":"\#(code)"}"#)
        case .offline:
            throw URLError(.notConnectedToInternet)
        case .held(let gate, let json):
            await gate.wait()
            return (.ok, json)
        }
    }

    private let state: Mutex<[String: [GoalSetupServerStub.Answer]]>
}
