import NuToriCore
import SwiftUI

/// 値が変わったときに、その「とき」の触覚を鳴らす。型は環境の `hapticTrial` から引く
struct HapticOnChange<Trigger: Equatable>: ViewModifier {
    let moment: HapticMoment
    let trigger: Trigger
    let condition: @Sendable (Trigger, Trigger) -> Bool

    func body(content: Content) -> some View {
        let feedback = trial[moment].feedback
        return content.sensoryFeedback(trigger: trigger) { [condition] old, new in
            condition(old, new) ? feedback : nil
        }
    }

    @Environment(\.hapticTrial) private var trial
}

extension View {
    /// trigger が変わり、condition が真のときに、その「とき」の触覚を鳴らす
    func haptic<Trigger: Equatable>(
        _ moment: HapticMoment, trigger: Trigger,
        when condition: @escaping @Sendable (_ old: Trigger, _ new: Trigger) -> Bool = { _, _ in
            true
        }
    ) -> some View {
        modifier(HapticOnChange(moment: moment, trigger: trigger, condition: condition))
    }
}
