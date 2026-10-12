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

    @Suite("記録を1件保存してあるとき")
    @MainActor
    struct Saved {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let saved: SentText

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            cache.context.autosaveEnabled = false
            saved = try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "朝ごはん")
            try cache.upsert(saved)
            try cache.context.save()
        }

        @Test("保存の前に足した記録を、同じ保存の前に読めること")
        func readsUnsavedRecord() throws {
            let added = try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "昼ごはん")

            try cache.upsert(added)

            #expect(Set(try cache.all()) == [saved, added])
        }

        @Test("保存の前に足した記録を、同じ保存の前に消せること")
        func removesUnsavedRecord() throws {
            let added = try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "昼ごはん")
            try cache.upsert(added)

            try cache.remove(id: added.id)

            #expect(try cache.savedRecords() == [saved])
        }

        @Test("保存の前に同じ ID を2回足すと、行を増やさず、あとの値になること")
        func upsertsSameIdTwiceBeforeSaving() throws {
            let id = UUID()
            try cache.upsert(try SwiftDataKeyedRecordCacheTests.sentText(id: id, body: "昼ごはん"))
            let latest = try SwiftDataKeyedRecordCacheTests.sentText(id: id, body: "昼ごはんと味噌汁")

            try cache.upsert(latest)

            #expect(Set(try cache.savedRecords()) == [saved, latest])
        }

        @Test("消した記録と同じ ID を、同じ保存の前に足し直すと、足した値が残ること")
        func upsertsRemovedIdBeforeSaving() throws {
            let again = try SwiftDataKeyedRecordCacheTests.sentText(
                id: saved.id, body: "朝ごはんとコーヒー")
            try cache.remove(id: saved.id)

            try cache.upsert(again)

            #expect(try cache.savedRecords() == [again])
        }

        @Test("キャッシュに無い ID を消しても、何も変わらないこと")
        func skipsMissingId() throws {
            try cache.remove(id: UUID())

            #expect(try cache.savedRecords() == [saved])
        }

        @Test("保存の前に足した記録も、すべて消せること")
        func removesAllIncludingUnsaved() throws {
            try cache.upsert(
                try SwiftDataKeyedRecordCacheTests.sentText(id: UUID(), body: "昼ごはん"))

            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }

        @Test("保存の前に値を替えた記録も、すべて消せること")
        func removesAllIncludingRevised() throws {
            try cache.upsert(
                try SwiftDataKeyedRecordCacheTests.sentText(id: saved.id, body: "朝ごはんとコーヒー"))

            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }

        @Test("すべて消したあと、同じ保存の前には1件も読めないこと")
        func readsNothingAfterRemovingAll() throws {
            try cache.removeAll()

            #expect(try cache.all().isEmpty)
        }

        @Test("すべて消してから、同じ保存の前に同じ ID を足し直すと、足した値が残ること")
        func upsertsAfterRemovingAll() throws {
            let again = try SwiftDataKeyedRecordCacheTests.sentText(
                id: saved.id, body: "朝ごはんとコーヒー")
            try cache.removeAll()

            try cache.upsert(again)

            #expect(try cache.savedRecords() == [again])
        }
    }
}
