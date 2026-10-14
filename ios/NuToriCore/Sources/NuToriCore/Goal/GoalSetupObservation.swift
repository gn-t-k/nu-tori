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
        /// 止まった場所（下見の答えを待っているあいだを含む）
        case stopped
    }

    public enum Choice: Sendable, Equatable {
        case gentle
        case standard
        case hard
        case custom
        case maintain
    }
}
