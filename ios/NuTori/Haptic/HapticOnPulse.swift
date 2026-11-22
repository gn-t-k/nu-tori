import NuToriCore
import SwiftUI

/// 押した操作の合図が変わったときに、押した操作の触覚を鳴らす。型は環境の `hapticTrial` から引く
struct HapticOnPulse: ViewModifier {
    let pulse: HapticPulse

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: pulse) { [trial] _, new in
            new.moment.flatMap { trial[$0].feedback }
        }
    }

    @Environment(\.hapticTrial) private var trial
}

extension View {
    func haptic(_ pulse: HapticPulse) -> some View {
        modifier(HapticOnPulse(pulse: pulse))
    }
}
