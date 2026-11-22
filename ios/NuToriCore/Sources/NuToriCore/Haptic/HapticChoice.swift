/// 触覚の型。SwiftUI の `SensoryFeedback` のうち選べるものと、鳴らさないこと
public enum HapticChoice: CaseIterable, Sendable {
    case silent
    case success
    case warning
    case error
    case selection
    case lightImpact
    case mediumImpact
    case heavyImpact
    case softImpact
    case rigidImpact
}
