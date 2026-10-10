import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 返事の、登録簿の1行。取りに行った返事をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`AiUtteranceSyncing`）
nonisolated struct AiUtteranceRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 届いた順に返事を書く。送った文章がまだ無い返事も置く（届く順は約束しない）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        for utterance in syncing.current(from: changes) {
            try CachedAiUtterance.upsert(utterance, in: cache)
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedAiUtterance.self)
    }

    private let syncing = AiUtteranceSyncing()
}
