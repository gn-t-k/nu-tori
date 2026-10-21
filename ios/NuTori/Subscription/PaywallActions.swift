import NuToriCore

/// 課金画面とアカウントの画面の「サブスクリプション」の行が、StoreKit と PostHog に触れる口
struct PaywallActions {
    /// 開いたときの今日で、まとめの次の更新日を書く
    let clock: DeviceClock
    let purchases: SubscriptionPurchases
    let capture: (ClientUsageEvent) async -> Void
}
