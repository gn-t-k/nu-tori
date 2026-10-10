import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 送った文章の、登録簿の1行。取りに行った変更と今の値をキャッシュに当てる。
/// 送る書き込みの形と、変更の見分け方は `SentTextSyncing`（NuToriCore）に置く
nonisolated struct SentTextRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 今の値を書いてから、外す送った文章（受け付けなかった作る書き込み）を消す。置き場に無い文章は読み飛ばす
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for sentText in current.sentTexts {
            try CachedSentText.upsert(sentText, in: cache)
        }
        for sentTextId in current.removedSentTextIds {
            if let row = try CachedSentText.find(id: sentTextId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedSentText.self)
    }

    private let syncing = SentTextSyncing()
}
