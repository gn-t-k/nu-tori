import NuToriCore
import SwiftUI

/// 課金画面をシートで開く。開いたところと、開いたときの状態を `Request` で受け取る。
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

    /// テストユーザーには開かない。開く前に `Request.init` が nil を返す
    init(request: Request, actions: PaywallActions, onClose: @escaping () -> Void) {
        self.content = request.content
        self.storefront = actions.storefront
        self.onClose = onClose
        _session = State(
            initialValue: PaywallSession(
                entry: request.entry, standing: request.standing,
                purchases: actions.purchases, capture: actions.capture))
    }

    /// 課金画面を開く求め。`.sheet(item:)` に渡す
    struct Request: Identifiable {
        let entry: ClientUsageEvent.PaywallEntry
        let standing: SubscriptionStanding
        let content: PaywallContent

        var id: ClientUsageEvent.PaywallEntry { entry }

        /// テストユーザーなら nil。文は開いたときの状態と今日で決め、開いているあいだに買って状態が変わっても描き替えない
        init?(
            entry: ClientUsageEvent.PaywallEntry, standing: SubscriptionStanding, today: CalendarDay
        ) {
            guard let content = PaywallContent(standing: standing, today: today) else { return nil }
            self.entry = entry
            self.standing = standing
            self.content = content
        }
    }

    private let content: PaywallContent
    private let storefront: PaywallStorefront
    @State private var session: PaywallSession
}

extension View {
    /// 課金画面を開く口。`request` に値を入れると開き、閉じると nil に戻す
    func paywallSheet(_ request: Binding<PaywallScreenContainer.Request?>, actions: PaywallActions)
        -> some View
    {
        sheet(item: request) { opened in
            PaywallScreenContainer(request: opened, actions: actions) {
                request.wrappedValue = nil
            }
        }
    }
}
