import NuToriCore
import SwiftData

/// キャッシュのサブスクリプションの状態の行と、記録との行き来。SwiftData の adapter（`SwiftDataSingleRecordCache`）が使う
extension CachedSubscriptionStatus: SingleCacheRow {
    nonisolated func record() -> SubscriptionStatus? {
        subscriptionStatus()
    }
}
