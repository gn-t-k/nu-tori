import NuToriCore

/// 課金画面とアカウントの画面の「サブスクリプション」の行が、StoreKit と PostHog に触れる口
struct PaywallActions {
    let purchases: SubscriptionPurchases
    let capture: (ClientUsageEvent) async -> Void
    let storefront: PaywallStorefront
}
