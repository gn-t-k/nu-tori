import NuToriCore
import SwiftUI

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
