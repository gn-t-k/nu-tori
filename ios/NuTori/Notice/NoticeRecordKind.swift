import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 知らせの、登録簿の1行。取りに行った変更と今の値をキャッシュに当てる。
/// 送る書き込みの形と、変更の見分け方は `NoticeSyncing`（NuToriCore）に置く
nonisolated struct NoticeRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 今の値を書いてから、外す知らせを消す。置き場に無い知らせは読み飛ばす
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for notice in current.notices {
            try CachedNotice.upsert(notice, in: cache)
        }
        for noticeId in current.removedNoticeIds {
            if let row = try CachedNotice.find(id: noticeId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedNotice.self)
    }

    private let syncing = NoticeSyncing()
}
