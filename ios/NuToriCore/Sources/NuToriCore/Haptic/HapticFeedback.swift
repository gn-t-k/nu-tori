/// 触覚の型。SwiftUI の `SensoryFeedback` のうち、このアプリで使うもの（DESIGN.md の「Haptics」）
public enum HapticFeedback: Equatable, Sendable {
    /// 結果が出た: できた
    case success
    /// 結果が出た: できたが、見てほしいことがある
    case warning
    /// 結果が出た: できなかった
    case error
    /// 見ている値が、1つ隣へ変わった
    case selection
}
