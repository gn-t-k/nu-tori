/// 目標の設定の流れで、いま出すページ
public enum GoalSetupPage: Sendable, Equatable {
    case direction
    case deadline
    /// 次が足りない値か目標案かが、下見の答えを待たないと分からない（初めての目標）
    case awaitingPreview
    case missingValues
    /// 減量・増量の目標案。案が届くまでは `GoalSetupFlow.proposals` が nil で、届く場所の高さを取って待つ
    case proposals
    case customTargetWeight
    /// 維持のページ。値が届くまでは `GoalSetupFlow.proposals` が nil
    case maintenance
    /// 減量の目標案を1つも出せないので断るページ（「維持にする」「戻る」）
    case loseUnavailable
    /// 電波が無くて、下見か目標案の答えが要る場所で止まった（「もう一度試す」）
    case stopped(StopPlace)

    public enum StopPlace: Sendable, Equatable {
        /// 足りない値より前。「…インターネットにつながると、続きに進めます。」
        case beforeMissingValues
        /// 目標案の前。「…インターネットにつながると、目標案を出せます。」
        case beforeProposals
    }
}
