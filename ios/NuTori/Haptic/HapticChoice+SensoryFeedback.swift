import NuToriCore
import SwiftUI

extension HapticChoice {
    /// SwiftUI で鳴らす触覚。鳴らさないときは無い
    var feedback: SensoryFeedback? {
        switch self {
        case .silent: nil
        case .success: .success
        case .warning: .warning
        case .error: .error
        case .selection: .selection
        case .increase: .increase
        case .decrease: .decrease
        case .lightImpact: .impact(weight: .light)
        case .mediumImpact: .impact(weight: .medium)
        case .heavyImpact: .impact(weight: .heavy)
        case .softImpact: .impact(flexibility: .soft)
        case .rigidImpact: .impact(flexibility: .rigid)
        }
    }
}
