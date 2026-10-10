import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 送った文章の状態の、登録簿の1行。取りに行った状態をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`SentTextStatusSyncing`）
nonisolated struct SentTextStatusRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 届いた順に状態を書く。送った文章がまだ無い状態も置く（届く順は約束しない）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        for status in syncing.current(from: changes) {
            try CachedSentTextStatus.write(
                status.status, forSentTextId: status.sentTextId, in: cache)
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedSentTextStatus.self)
    }

    private let syncing = SentTextStatusSyncing()
}
