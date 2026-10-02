import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュのアカウントの設定と、通知の許可を読んで、アカウントの画面に渡す
struct AccountScreenContainer: View {
    let actions: AccountActions
    let onClose: () -> Void

    var body: some View {
        AccountScreen(
            sendsUsageData: UsageDataSetting.sendsUsageData(
                cachedSettings.first?.accountSettings()),
            cameraAccess: CameraAccess.current(),
            notificationPermission: notificationPermission,
            deletion: .idle,
            actions: actions,
            onClose: onClose
        )
        .task {
            notificationPermission = await actions.notificationPermission()
        }
        // 通知の許可を設定で変えても、カメラと違ってアプリは終わらないので、戻ったときに読み直す
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { notificationPermission = await actions.notificationPermission() }
        }
    }

    @Query private var cachedSettings: [CachedAccountSettings]
    @Environment(\.scenePhase) private var scenePhase
    /// 読み終えるまでは無い
    @State private var notificationPermission: NotificationPermission?
}
