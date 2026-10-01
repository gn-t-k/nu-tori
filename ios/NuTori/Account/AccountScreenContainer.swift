import NuToriCore
import SwiftData
import SwiftUI

/// キャッシュのアカウントの設定を読んで、アカウントの画面に渡す
struct AccountScreenContainer: View {
    let actions: AccountActions
    let onClose: () -> Void

    var body: some View {
        AccountScreen(
            sendsUsageData: UsageDataSetting.sendsUsageData(
                cachedSettings.first?.accountSettings()),
            deletion: .idle,
            actions: actions,
            onClose: onClose
        )
    }

    @Query private var cachedSettings: [CachedAccountSettings]
}
