import NuToriCore
import SwiftData

/// キャッシュのアカウントの設定の行と、記録との行き来。SwiftData の adapter（`SwiftDataSingleRecordCache`）が使う
extension CachedAccountSettings: SingleCacheRow {
    nonisolated func record() -> AccountSettings? {
        accountSettings()
    }
}
