import NuToriCore
import SwiftUI

/// 合図が変わったときに、その「とき」の触覚を鳴らす
struct HapticOnPulse: ViewModifier {
    let pulse: HapticPulse

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: pulse) { _, new in
            new.moment?.feedback.sensoryFeedback
        }
    }
}

extension View {
    func haptic(_ pulse: HapticPulse) -> some View {
        modifier(HapticOnPulse(pulse: pulse))
    }
}
