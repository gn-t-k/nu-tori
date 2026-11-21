#if DEBUG
    import SwiftUI

    // 場面は画面の中のボタンで流すので、状態の見本を持たない
    #Preview {
        MotionGalleryScreen(accountActions: .noop, paywallActions: .noop, onClose: {})
    }
#endif
