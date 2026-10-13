import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// 行と記録の対応は、種類ごとのテスト（`Cached…CacheTests`）で確かめる。ここでは、保存の前に続けて読み書きしたときの adapter を確かめる。
/// 当て方（`CacheApplying`）は、1回の保存の前に、足す・消すを続けて呼ぶ
@Suite("SwiftData の、ID で引く記録のキャッシュ")
struct SwiftDataKeyedRecordCacheTests {
    static func sentText(id: UUID, body: String) throws -> SentText {
        SentText(
            id: id, body: body, sentAt: Date(timeIntervalSince1970: 1_790_046_600),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
    }

    /// 記録を1件保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func savedCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedSentText>,
        saved: SentText
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedSentText>(
            context: store.container.mainContext)
        cache.context.autosaveEnabled = false
        let saved = try sentText(id: UUID(), body: "朝ごはん")
        try cache.upsert(saved)
        try cache.context.save()
        return (store, cache, saved)
    }

    @Suite("記録を1件保存してあるとき")
    @MainActor
    struct Saved {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText
        let added: SentText

        init() throws {
            (store, cache, saved) = try SwiftDataKeyedRecordCacheTests.savedCache()
            added = try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "昼ごはん")
        }

        @Test("保存の前に足した記録を、同じ保存の前に読めること")
        func readsUnsavedRecord() throws {
            try cache.upsert(added)

            #expect(Set(try cache.all()) == [saved, added])
        }

        @Test("キャッシュに無い ID を消しても、何も変わらないこと")
        func skipsMissingId() throws {
            try cache.remove(id: added.id)

            #expect(try cache.savedRecords() == [saved])
        }

        @Test("すべて消したあと、同じ保存の前には1件も読めないこと")
        func readsNothingAfterRemovingAll() throws {
            try cache.removeAll()

            #expect(try cache.all().isEmpty)
        }
    }

    @Suite("記録を1件保存してあり、保存の前にもう1件足したとき")
    @MainActor
    struct AddedBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText
        let added: SentText
        let latest: SentText

        init() throws {
            (store, cache, saved) = try SwiftDataKeyedRecordCacheTests.savedCache()
            added = try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "昼ごはん")
            latest = try SwiftDataKeyedRecordCacheTests.sentText(id: added.id, body: "昼ごはんと味噌汁")
            try cache.upsert(added)
        }

        @Test("足した記録を、同じ保存の前に消せること")
        func removesUnsavedRecord() throws {
            try cache.remove(id: added.id)

            #expect(try cache.savedRecords() == [saved])
        }

        @Test("同じ ID をもう一度足すと、行を増やさず、あとの値になること")
        func upsertsSameIdTwiceBeforeSaving() throws {
            try cache.upsert(latest)

            #expect(Set(try cache.savedRecords()) == [saved, latest])
        }

        @Test("足した記録も、すべて消せること")
        func removesAllIncludingUnsaved() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("保存してある記録の値を、保存の前に替えたとき")
    @MainActor
    struct RevisedBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText

        init() throws {
            (store, cache, saved) = try SwiftDataKeyedRecordCacheTests.savedCache()
            try cache.upsert(
                try SwiftDataKeyedRecordCacheTests.sentText(id: saved.id, body: "朝ごはんとコーヒー"))
        }

        @Test("値を替えた記録も、すべて消せること")
        func removesAllIncludingRevised() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("保存してある記録を、保存の前に消したとき")
    @MainActor
    struct RemovedBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText
        let again: SentText

        init() throws {
            (store, cache, saved) = try SwiftDataKeyedRecordCacheTests.savedCache()
            again = try SwiftDataKeyedRecordCacheTests.sentText(id: saved.id, body: "朝ごはんとコーヒー")
            try cache.remove(id: saved.id)
        }

        @Test("同じ ID を、同じ保存の前に足し直すと、足した値が残ること")
        func upsertsRemovedIdBeforeSaving() throws {
            try cache.upsert(again)

            #expect(try cache.savedRecords() == [again])
        }
    }

    @Suite("保存してある記録を、保存の前にすべて消したとき")
    @MainActor
    struct RemovedAllBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText
        let again: SentText

        init() throws {
            (store, cache, saved) = try SwiftDataKeyedRecordCacheTests.savedCache()
            again = try SwiftDataKeyedRecordCacheTests.sentText(id: saved.id, body: "朝ごはんとコーヒー")
            try cache.removeAll()
        }

        @Test("同じ ID を、同じ保存の前に足し直すと、足した値が残ること")
        func upsertsAfterRemovingAll() throws {
            try cache.upsert(again)

            #expect(try cache.savedRecords() == [again])
        }
    }
}
