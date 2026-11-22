/// 触覚の型。SwiftUI の `SensoryFeedback` のうち iPhone で鳴るものと、鳴らさないこと。impact の強さ（intensity）は既定のままにする
public enum HapticChoice: CaseIterable, Sendable {
    case silent
    case success
    case warning
    case error
    case selection
    case increase
    case decrease
    case lightImpact
    case mediumImpact
    case heavyImpact
    case softImpact
    case rigidImpact
}
