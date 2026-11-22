#if DEBUG
    import NuToriCore
    import SwiftUI

    // 型は画面の中で選ぶので、状態の見本を持たない
    #Preview {
        @Previewable @State var trial = HapticTrial.standard
        HapticTrialSheet(trial: $trial)
    }
#endif
