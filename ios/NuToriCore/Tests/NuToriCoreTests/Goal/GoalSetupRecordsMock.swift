import Foundation
import NuToriAPI
import NuToriCore
import Synchronization

/// 目標の設定の流れが同期の段取りに頼むことの差し替え。頼まれた順に控える
final class GoalSetupRecordsMock: GoalSetupRecords, Sendable {
    enum Call: Equatable {
        case sendWeightRecords
        case recordWeight(kilograms: Double)
        case applyGoalDecision([SyncChange])
        case respondToGoalSetupNotice
    }

    var calls: [Call] {
        state.withLock { $0.calls }
    }

    /// 体重記録を送り切れるか。テストの途中で電波が戻ったことにするときに替える
    var sendsWeightRecords: Bool {
        get { state.withLock { $0.sendsWeightRecords } }
        set { state.withLock { $0.sendsWeightRecords = newValue } }
    }

    static func ok(sendsWeightRecords: Bool = true) -> GoalSetupRecordsMock {
        GoalSetupRecordsMock(sendsWeightRecords: sendsWeightRecords, applyGoalDecisionError: nil)
    }

    /// 応答の記録をキャッシュに当てるときに `applyGoalDecisionError` を投げる
    static func error(_ applyGoalDecisionError: any Error) -> GoalSetupRecordsMock {
        GoalSetupRecordsMock(
            sendsWeightRecords: true, applyGoalDecisionError: applyGoalDecisionError)
    }

    func goalSetupStart(today: CalendarDay) async throws -> GoalSetupStart {
        .first(firstUseDay: today, hasWeightRecords: true)
    }

    func sendWeightRecordsForGoalSetup() async -> Bool {
        state.withLock { state in
            state.calls.append(.sendWeightRecords)
            return state.sendsWeightRecords
        }
    }

    func recordWeight(kilograms: Double, at instant: Date, in timeZone: TimeZone) async throws {
        state.withLock { $0.calls.append(.recordWeight(kilograms: kilograms)) }
    }

    func applyGoalDecision(_ changes: [SyncChange]) async throws {
        state.withLock { $0.calls.append(.applyGoalDecision(changes)) }
        if let applyGoalDecisionError {
            throw applyGoalDecisionError
        }
    }

    /// キャッシュに保存できなかったことにする失敗
    struct CacheSaveFailure: Error {}

    func respondToGoalSetupNotice() async {
        state.withLock { $0.calls.append(.respondToGoalSetupNotice) }
    }

    private struct State {
        var calls: [Call] = []
        var sendsWeightRecords: Bool
    }

    private let state: Mutex<State>
    private let applyGoalDecisionError: (any Error)?

    private init(sendsWeightRecords: Bool, applyGoalDecisionError: (any Error)?) {
        state = Mutex(State(sendsWeightRecords: sendsWeightRecords))
        self.applyGoalDecisionError = applyGoalDecisionError
    }
}
