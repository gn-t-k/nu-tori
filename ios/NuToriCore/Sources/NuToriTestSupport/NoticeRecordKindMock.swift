public import NuToriAPI
public import NuToriCore

/// 知らせの、メモリのキャッシュに当てる登録簿の1行。アプリの `NoticeRecordKind` と同じ振る舞い
public struct NoticeRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for notice in current.notices {
            cache.upsert(notice)
        }
        for noticeId in current.removedNoticeIds {
            cache.remove(noticeId: noticeId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearNotices()
    }

    private let syncing = NoticeSyncing()
}
