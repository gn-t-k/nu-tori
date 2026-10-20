/// 目標の設定の流れが、端末の PostHog に送る出来事として知らせる値。体重・目標体重・kcal と身体データは持たない
public enum GoalSetupObservation: Sendable, Equatable {
    /// `goal_setup_opened`
    case opened(entry: Entry, isRestart: Bool, resumed: Bool)
    /// `goal_setup_closed`
    case closed(page: Page)
    /// `goal_decided`
    case decided(choice: Choice, recalculated: Bool)
    /// `goal_plans_unavailable`。立て直しでは逆算を問わないので nil
    case plansUnavailable(canBackCalculate: Bool?)

    /// 開いたところ
    public enum Entry: Sendable, Equatable {
        case noticeCard
        case unansweredNoticeLine
        case daySummary
        case weightScreen
        /// 達成・期限の知らせと日のまとめの「次の目標を選ぶ」
        case chooseNextGoal
        /// 期限後の維持の知らせと日のまとめの「次の目標を立てる」
        case setNextGoal
        /// 目標の画面の「目標を切り替える」
        case switchGoal
    }

    /// 閉じたページ
    public enum Page: Sendable, Equatable {
        case direction
        case deadline
        case missingValues
        case proposals
        case customTargetWeight
        case maintenance
        case loseUnavailable
        /// 電波が無くて止まった場所
        case stopped
        /// 次が足りない値か目標案かが分かるまで、下見の答えを待っている場所
        case awaitingPreview
    }

    public enum Choice: Sendable, Equatable {
        case gentle
        case standard
        case hard
        case custom
        case maintain
    }
}
