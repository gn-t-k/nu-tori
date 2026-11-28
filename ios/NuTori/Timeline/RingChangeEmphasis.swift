import NuToriCore
import SwiftUI

/// 食事を記録して帯の1日の丸の塗り（`arcs`）が変わったときに、丸を一瞬ふくらませて目を向けさせる（#325）。
/// 開いたときの最初の描画では動かさない。「視差効果を減らす」では大きさが動くのを外し、塗りが伸びるだけにする
struct RingChangeEmphasis: ViewModifier {
    let arcs: DayRing.Arcs?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .keyframeAnimator(initialValue: 1.0, trigger: arcs) { view, scale in
                    view.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.25, duration: 0.18, spring: .smooth)
                    SpringKeyframe(1.0, duration: 0.4, spring: .smooth)
                }
        }
    }
}
