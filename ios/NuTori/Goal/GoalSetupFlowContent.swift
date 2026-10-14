import NuToriAPI
import NuToriCore

/// 目標の設定の流れのカードが描く値。外側が流れ（`GoalSetupFlow`）から読んで渡す
struct GoalSetupFlowContent {
    let page: GoalSetupPage
    let progress: GoalSetupFlow.Progress
    let direction: GoalSetupDirection?
    let deadline: CalendarDay
    let deadlineChoices: GoalDeadlineChoices
    let missingValues: GoalSetupMissingValues?
    let proposals: GoalProposals?
    let selectedPace: GoalProposals.Pace?
    let customTargetWeight: CustomTargetWeight?
    let decision: GoalSetupFlow.Decision
    let unreachableRequest: GoalSetupFlow.UnreachableRequest?
    let showsRecalculated: Bool
    let usedValues: GoalSetupUsedValues?
    let pastWeightRecordDay: CalendarDay?

    /// 「この目標で始める」を押したあと。ほかを薄くして押せなくする
    var isDeciding: Bool {
        decision != .idle
    }
}

extension GoalSetupFlowContent {
    @MainActor
    init(_ flow: GoalSetupFlow) {
        self.init(
            page: flow.page,
            progress: flow.progress,
            direction: flow.direction,
            deadline: flow.deadline,
            deadlineChoices: flow.deadlineChoices,
            missingValues: flow.missingValues,
            proposals: flow.proposals,
            selectedPace: flow.selectedPace,
            customTargetWeight: flow.customTargetWeight,
            decision: flow.decision,
            unreachableRequest: flow.unreachableRequest,
            showsRecalculated: flow.showsRecalculated,
            usedValues: flow.usedValues,
            pastWeightRecordDay: flow.pastWeightRecordDay)
    }
}
