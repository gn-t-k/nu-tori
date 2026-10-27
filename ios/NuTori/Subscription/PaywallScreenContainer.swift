import NuToriCore
import SwiftUI

/// 課金画面をシートで開く。開いたところと、開いたときの状態を `PaywallRequest` で受け取る。
/// 結びついたら閉じ、閉じたら PostHog に StoreKit の結果を送る
struct PaywallScreenContainer: View {
    let onClose: () -> Void

    var body: some View {
        PaywallScreen(
            content: content,
            storefront: storefront,
            purchaseToken: session.purchaseToken,
            message: session.message,
            purchaseCompleted: session.purchaseCompleted(_:),
            purchaseFailed: session.purchaseFailed,
            restore: session.restore,
            onClose: onClose
        )
        .task { await session.open() }
        .onChange(of: session.isFinished) { _, isFinished in
            if isFinished { onClose() }
        }
        // 下へ送って閉じたときも送る
        .onDisappear {
            let session = session
            Task { await session.close() }
        }
    }

    /// テストユーザーには開かない。開く前に `PaywallRequest.init` が nil を返す
    init(request: PaywallRequest, actions: PaywallActions, onClose: @escaping () -> Void) {
        self.content = request.content
        self.storefront = actions.storefront
        self.onClose = onClose
        _session = State(
            initialValue: PaywallSession(
                entry: request.entry, standing: request.standing,
                purchases: actions.purchases, capture: actions.capture))
    }

    private let content: PaywallContent
    private let storefront: PaywallStorefront
    @State private var session: PaywallSession
}

extension View {
    /// 課金画面を開く口。`request` に値を入れると開き、閉じると nil に戻す
    func paywallSheet(_ request: Binding<PaywallRequest?>, actions: PaywallActions)
        -> some View
    {
        sheet(item: request) { opened in
            PaywallScreenContainer(request: opened, actions: actions) {
                request.wrappedValue = nil
            }
        }
    }
}
