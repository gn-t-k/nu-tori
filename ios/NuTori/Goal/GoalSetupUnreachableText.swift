import NuToriCore

/// インターネットにつながらないときの1行。DESIGN.md の Don't のとおり、つながるとできることを書く
enum GoalSetupUnreachableText {
    static func stopped(_ place: GoalSetupPage.StopPlace) -> String {
        switch place {
        case .beforeMissingValues:
            "インターネットにつながると、続きに進めます。"
        case .beforeProposals:
            "インターネットにつながると、目標案を出せます。"
        }
    }

    /// 自分で決める目標体重の要求が届かなかった
    static let customTargetWeight = "インターネットにつながると、1日の目安を出せます。"

    /// 目標を決める要求が届かなかった
    static let decision = "インターネットにつながると、目標を決められます。"
}
