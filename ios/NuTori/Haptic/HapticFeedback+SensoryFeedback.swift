import NuToriCore
import SwiftUI

extension HapticFeedback {
    /// SwiftUI で鳴らす触覚
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .error
        case .selection: .selection
        }
    }
}
