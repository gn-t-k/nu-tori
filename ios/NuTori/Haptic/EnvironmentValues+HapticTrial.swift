import NuToriCore
import SwiftUI

extension EnvironmentValues {
    /// 触覚を鳴らすときごとの型。「動きの見本」だけが選び直したものを渡し、ほかはいつも本番の型
    @Entry var hapticTrial = HapticTrial.standard
}
