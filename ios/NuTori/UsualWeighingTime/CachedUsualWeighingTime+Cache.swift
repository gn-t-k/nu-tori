import NuToriCore
import SwiftData

/// キャッシュのいつもの時刻の行と、記録との行き来。SwiftData の adapter（`SwiftDataSingleRecordCache`）が使う
extension CachedUsualWeighingTime: SingleCacheRow {
    nonisolated func record() -> UsualWeighingTime? {
        usualWeighingTime()
    }
}
