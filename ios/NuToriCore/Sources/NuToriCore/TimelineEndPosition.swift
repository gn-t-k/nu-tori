/// タイムラインの中身の下端が、見えている所のどこにあるか。
/// 見えている所の下は入力欄に隠れるので、下端がそこにあると、足したカードや伸びる返事が入力欄の下に隠れる（#469）
public enum TimelineEndPosition: Equatable, Sendable {
    /// 入力欄の上に見えている（一番下にいる）
    case shown
    /// 入力欄の下に隠れている
    case underComposer
    /// 入力欄よりも下で、画面の外にある
    case offscreen

    /// - Parameters:
    ///   - visibleMaxY: 見えている所の下端。入力欄に隠れた分を含む
    ///   - hiddenByComposer: 見えている所の下で、入力欄に隠れた高さ
    ///   - contentHeight: 中身の高さ
    public init(visibleMaxY: Double, hiddenByComposer: Double, contentHeight: Double) {
        // 位置は小数で届くので、1 までのずれは下端ちょうどとみなす
        let end = contentHeight - 1
        if visibleMaxY - hiddenByComposer >= end {
            self = .shown
        } else if visibleMaxY >= end {
            self = .underComposer
        } else {
            self = .offscreen
        }
    }

    /// 止まったときに、また一番下を追うか。入力欄の下に隠れていても、一番下にいるとみなして追う
    public var followsWhenSettled: Bool {
        switch self {
        case .shown, .underComposer: true
        case .offscreen: false
        }
    }
}
