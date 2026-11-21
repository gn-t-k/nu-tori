import Foundation

/// 食事を記録して帯の1日の丸の塗りが変わったときに、丸へ目を向けさせる動き（#325）。
/// どれにするかは TestFlight の「動きの見本」で見比べて決める。決まったら、選んだもの以外を消す
enum RingEmphasis: String, CaseIterable, Identifiable {
    /// 塗りが伸びるだけ
    case none
    /// 塗りが伸びるあいだ、丸が一瞬ふくらんで戻る
    case pop
    /// 塗りが伸び終わったところで、丸のまわりに光の輪が広がって消える
    case glow

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "なし"
        case .pop: "ふくらむ"
        case .glow: "光る"
        }
    }

    /// 選んだ案を覚えておく置き場の名前。見本の画面で選ぶと、タイムラインの帯の丸にもそのまま効く
    static let storageKey = "ringEmphasis"

    /// まだ選んでいないときの案
    static let defaultValue = RingEmphasis.pop
}
