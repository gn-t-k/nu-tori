import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// いつもの時刻の、登録簿の1行。最後に届いた時刻をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`UsualWeighingTimeSyncing`）
nonisolated struct UsualWeighingTimeRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 届いていなければ何もしない。一度届いたら消えない
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        if let usualWeighingTime = syncing.current(from: changes) {
            try CachedUsualWeighingTime.write(usualWeighingTime, in: cache)
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedUsualWeighingTime.self)
    }

    private let syncing = UsualWeighingTimeSyncing()
}
