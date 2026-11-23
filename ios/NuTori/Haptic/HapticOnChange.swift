import NuToriCore
import SwiftUI

/// 値が変わったときに、その「とき」の触覚を鳴らす
struct HapticOnChange<Trigger: Equatable>: ViewModifier {
    let moment: HapticMoment
    let trigger: Trigger
    let condition: (Trigger, Trigger) -> Bool

    func body(content: Content) -> some View {
        let feedback = moment.feedback.sensoryFeedback
        return content.sensoryFeedback(trigger: trigger) { [condition] old, new in
            condition(old, new) ? feedback : nil
        }
    }
}

extension View {
    /// trigger が変わり、condition が真のときに、その「とき」の触覚を鳴らす
    func haptic<Trigger: Equatable>(
        _ moment: HapticMoment, trigger: Trigger,
        when condition: @escaping (_ old: Trigger, _ new: Trigger) -> Bool
    ) -> some View {
        modifier(HapticOnChange(moment: moment, trigger: trigger, condition: condition))
    }
}
