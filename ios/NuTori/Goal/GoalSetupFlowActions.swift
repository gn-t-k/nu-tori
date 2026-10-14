import NuToriAPI
import NuToriCore

/// 目標の設定の流れのカードの操作。外側が流れ（`GoalSetupFlow`）の操作をつなぐ。要求を出す操作は待たずに戻る
struct GoalSetupFlowActions {
    let close: () -> Void
    let chooseDirection: (GoalSetupDirection) -> Void
    let chooseDeadline: (CalendarDay) -> Void
    let proceedFromDeadline: () -> Void
    let enterMissingValues: (GoalSetupMissingValues.Entry) -> Void
    let proceedFromMissingValues: () -> Void
    let goBack: () -> Void
    let reviseMissingValues: () -> Void
    let retry: () -> Void
    let selectPace: (GoalProposals.Pace) -> Void
    let openCustomTargetWeight: () -> Void
    let setCustomTargetWeight: (Double) -> Void
    let chooseMaintainInstead: () -> Void
    let decide: () -> Void
}

extension GoalSetupFlowActions {
    @MainActor
    init(_ flow: GoalSetupFlow, close: @escaping () -> Void) {
        self.init(
            close: close,
            chooseDirection: { direction in Task { await flow.chooseDirection(direction) } },
            chooseDeadline: { flow.chooseDeadline($0) },
            proceedFromDeadline: { Task { await flow.proceedFromDeadline() } },
            enterMissingValues: { flow.enterMissingValues($0) },
            proceedFromMissingValues: { Task { await flow.proceedFromMissingValues() } },
            goBack: { flow.goBack() },
            reviseMissingValues: { flow.reviseMissingValues() },
            retry: { Task { await flow.retry() } },
            selectPace: { flow.selectPace($0) },
            openCustomTargetWeight: { flow.openCustomTargetWeight() },
            setCustomTargetWeight: { kilograms in
                Task { await flow.setCustomTargetWeight(kilograms) }
            },
            chooseMaintainInstead: { Task { await flow.chooseMaintainInstead() } },
            decide: { Task { await flow.decide() } })
    }
}

#if DEBUG
    extension GoalSetupFlowActions {
        /// プレビューの見本。どの操作も何もしない
        static var none: GoalSetupFlowActions {
            GoalSetupFlowActions(
                close: {}, chooseDirection: { _ in }, chooseDeadline: { _ in },
                proceedFromDeadline: {}, enterMissingValues: { _ in }, proceedFromMissingValues: {},
                goBack: {}, reviseMissingValues: {}, retry: {}, selectPace: { _ in },
                openCustomTargetWeight: {}, setCustomTargetWeight: { _ in },
                chooseMaintainInstead: {}, decide: {})
        }
    }
#endif
