import Foundation
import NuToriCore
import StoreKit
import SwiftUI

/// 課金画面。StoreKit の `SubscriptionStoreView`（月額と年額）の上に、宣伝の部分とまとめを置く。
/// 価格・期間・購入・規約のリンクは StoreKit が描き、払う額は購入ボタンに価格と期間を載せる形で `Product.displayPrice` から出す
struct PaywallScreen: View {
    let content: PaywallContent
    let storefront: PaywallStorefront
    let purchaseToken: PaywallSession.PurchaseToken
    /// 購入ボタンの上に出す1行
    let message: String?
    let purchaseCompleted: (AppStorePurchaseAttempt) async -> Void
    let purchaseFailed: () -> Void
    let restore: () async -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            storefrontView
                // 押せなくした課金の部分の外に置き、「購入を復元」と「閉じる」はいつも押せるようにする
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("購入を復元") {
                            Task {
                                isRestoring = true
                                await restore()
                                isRestoring = false
                            }
                        }
                        .disabled(isRestoring)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる", action: onClose)
                    }
                }
        }
    }

    @State private var isRestoring = false

    @ViewBuilder private var storefrontView: some View {
        switch storefront {
        case .storeKit:
            store
        #if DEBUG
            case .fixed(let purchase):
                fixedStore(purchase: purchase)
        #endif
        }
    }

    private var store: some View {
        SubscriptionStoreView(productIDs: SubscriptionProduct.ids.keys.sorted()) {
            marketing
        }
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .policies)
        .subscriptionStorePolicyDestination(url: PublicPages.terms, for: .termsOfService)
        .subscriptionStorePolicyDestination(url: PublicPages.privacyPolicy, for: .privacyPolicy)
        // 「購入を復元」と閉じるはツールバーに自前で置く。復元の結果（ほかのアカウントのもの、復元するものが無い）を1行で出すため
        .storeButton(.hidden, for: .restorePurchases, .cancellation)
        .inAppPurchaseOptions { _ in
            guard case .issued(let token) = purchaseToken else { return [] }
            return [.appAccountToken(token)]
        }
        .onInAppPurchaseCompletion { _, result in
            switch result {
            case .success(let purchaseResult):
                await purchaseCompleted(AppStorePurchaseAttempt(purchaseResult))
            case .failure:
                purchaseFailed()
            }
        }
        // 購入者のトークンを渡せないと、買ったサブスクリプションがどのアカウントのものか決まらないので、買わせない。
        // 選ぶところと購入ボタンだけを止める口は StoreKit に無いので、規約のリンクも一緒に押せなくなる
        .disabled(!canPurchase)
    }

    #if DEBUG
        /// UI テストの買うところ。宣伝の部分の下に、月額を買うボタンだけを置く
        private func fixedStore(
            purchase: @escaping (_ appAccountToken: UUID) async -> AppStorePurchaseAttempt
        ) -> some View {
            ScrollView {
                marketing
                Button("月額で始める") {
                    guard case .issued(let token) = purchaseToken else { return }
                    Task { await purchaseCompleted(await purchase(token)) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPurchase)
                .accessibilityIdentifier("paywall-purchase")
            }
        }
    #endif

    private var canPurchase: Bool {
        switch purchaseToken {
        case .issued: true
        case .requesting, .unavailable: false
        }
    }

    /// 宣伝の部分。まとめをいちばん下（選ぶところと購入ボタンのすぐ上）に置く
    private var marketing: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(content.headline)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(PaywallContent.features, id: \.self) { feature in
                        Label(feature, systemImage: "checkmark")
                            .font(.subheadline)
                    }
                }
                Text(PaywallContent.keepsWithoutSubscription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            summary
            if let message {
                Text(message)
                    .font(.footnote)
                    .accessibilityIdentifier("paywall-message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    /// 特商法 12 条の 6 の最終確認画面に当たる見込みのまとめ（#593）
    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let paymentStart = content.paymentStart {
                summaryItem("支払いが始まる日") { Text(paymentStart) }
            }
            summaryItem("自動更新") {
                Text(PaywallContent.renewal)
                ForEach(content.renewalSchedule, id: \.self) { BulletLine(text: $0) }
            }
            summaryItem("解約の方法") { Text(PaywallContent.cancellation) }
            Link("特定商取引法に基づく表記", destination: PublicPages.legal)
                .font(.footnote)
        }
    }

    private func summaryItem(_ title: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
            Group(content: value)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
