import NuToriCore
import SwiftUI

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

/// 塗り（`arcs`）が変わったときだけ、選んだ案の動きをする。開いたときの最初の描画では動かさない。
/// 「視差効果を減らす」では、ふくらむのも広がるのも位置や大きさが動くので、塗りが伸びるだけにする
struct RingChangeEmphasis: ViewModifier {
    let arcs: DayRing.Arcs?
    let diameter: CGFloat

    @AppStorage(RingEmphasis.storageKey) private var emphasis = RingEmphasis.defaultValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        switch reduceMotion ? .none : emphasis {
        case .none:
            content
        case .pop:
            content
                .keyframeAnimator(initialValue: 1.0, trigger: arcs) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.25, duration: 0.18, spring: .smooth)
                    SpringKeyframe(1.0, duration: 0.4, spring: .smooth)
                }
        case .glow:
            content
                .overlay {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: diameter, height: diameter)
                        .keyframeAnimator(initialValue: Halo(), trigger: arcs) { view, halo in
                            view.scaleEffect(halo.scale).opacity(halo.opacity)
                        } keyframes: { _ in
                            // 塗りが伸び終わる（記録の出入りと同じ 0.35 秒）のを待ってから広げる
                            KeyframeTrack(\.scale) {
                                LinearKeyframe(1.0, duration: 0.35)
                                CubicKeyframe(1.7, duration: 0.55)
                            }
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(0.0, duration: 0.35)
                                LinearKeyframe(0.8, duration: 0.01)
                                CubicKeyframe(0.0, duration: 0.54)
                            }
                        }
                        .allowsHitTesting(false)
                }
        }
    }

    private struct Halo {
        var scale = 1.0
        var opacity = 0.0
    }
}
