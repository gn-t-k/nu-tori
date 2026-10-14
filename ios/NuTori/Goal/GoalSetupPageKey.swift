import NuToriCore

/// ページを見分ける値。ページが替わったときの動きと、ページを送ったあとの自動のスクロールに使う
struct GoalSetupPageKey: Hashable {
    init(_ page: GoalSetupPage) {
        name =
            switch page {
            case .direction: "direction"
            case .deadline: "deadline"
            case .awaitingPreview: "awaiting-preview"
            case .missingValues: "missing-values"
            case .proposals: "proposals"
            case .customTargetWeight: "custom-target-weight"
            case .maintenance: "maintenance"
            case .loseUnavailable: "lose-unavailable"
            case .stopped(.beforeMissingValues): "stopped-before-missing-values"
            case .stopped(.beforeProposals): "stopped-before-proposals"
            }
    }

    private let name: String
}
