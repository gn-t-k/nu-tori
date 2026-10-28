import Foundation
import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュのアカウントの設定とサブスクリプションの状態、通知の許可、自動更新を読んで、アカウントの画面に渡す
struct AccountScreenContainer: View {
    /// 開いたときの今とタイムゾーンで、サブスクリプションの状態と課金画面のまとめの次の更新日を書く
    let now: () -> Date
    let timeZone: () -> TimeZone
    let actions: AccountActions
    let paywallActions: PaywallActions
    let onClose: () -> Void

    var body: some View {
        let standing = cachedSubscriptionStatuses.first?.subscriptionStatus().map {
            SubscriptionStanding(
                status: $0, now: now(), timeZone: timeZone())
        }
        AccountScreen(
            subscription: standing.map {
                AccountSubscriptionRow(
                    standing: $0, autoRenewal: autoRenewal,
                    timeZone: timeZone())
            },
            openPaywall: {
                guard let standing else { return }
                paywallRequest = PaywallRequest(
                    entry: .accountRow, standing: standing,
                    today: CalendarDay(containing: now(), in: timeZone()))
            },
            sendsUsageData: UsageDataSetting.sendsUsageData(
                cachedSettings.first?.accountSettings()),
            cameraAccess: CameraAccess.current(),
            notificationPermission: notificationPermission,
            deletion: .idle,
            signOut: .idle,
            appVersion: Bundle.main.appVersion,
            appBuild: Bundle.main.appBuild,
            actions: actions,
            onClose: onClose
        )
        // 通知の許可を設定で変えても、カメラと違ってアプリは終わらないので、前面に戻ったときに読み直す
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            notificationPermission = await actions.notificationPermission()
        }
        // iPhone の設定で解約して戻ったときと、課金画面を閉じたときに読み直す
        .task(id: [scenePhase == .active, paywallRequest == nil]) {
            guard scenePhase == .active, paywallRequest == nil else { return }
            autoRenewal = await actions.autoRenewal()
        }
        .paywallSheet($paywallRequest, actions: paywallActions)
    }

    @Query private var cachedSettings: [CachedAccountSettings]
    @Query private var cachedSubscriptionStatuses: [CachedSubscriptionStatus]
    @Environment(\.scenePhase) private var scenePhase
    /// 読み終えるまでは無い
    @State private var notificationPermission: NotificationPermission?
    /// 読み終えるまでは、自動更新がオンのときと同じ形で描く
    @State private var autoRenewal = SubscriptionPurchases.AutoRenewal.unknown
    @State private var paywallRequest: PaywallRequest?
}
