import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("食事のキャッシュの行")
struct CachedMealCacheTests {
    static func meal(id: UUID, entry: Meal.Entry, photoIds: [UUID]) throws -> Meal {
        Meal(
            id: id, eatenAt: Date(timeIntervalSince1970: 1_790_046_600),
            eatenUtcOffsetSeconds: 32_400, sentAt: Date(timeIntervalSince1970: 1_790_046_660.25),
            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), entry: entry,
            photoIds: photoIds)
    }

    /// 写真の食事と文章の食事を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedMeal>, picked: Meal,
        written: Meal
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedMeal>(context: store.container.mainContext)
        // 写真の並びは ID の順と逆にして、並び順を保つことを確かめる
        let picked = try meal(
            id: UUID(), entry: .picked,
            photoIds: [
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c2")),
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")),
            ])
        let written = try meal(id: UUID(), entry: .written(sentTextId: UUID()), photoIds: [])
        try cache.upsert(picked)
        try cache.upsert(written)
        try cache.context.save()
        return (store, cache, picked, written)
    }

    @Suite("写真の食事と文章の食事を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedMeal>
        let picked: Meal
        let written: Meal

        init() throws {
            (store, cache, picked, written) = try CachedMealCacheTests.filledCache()
        }

        @Test("足した食事と同じ食事を、写真の並び順と入口を保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [picked, written])
        }

        @Suite("同じ ID の食事を足すとき")
        @MainActor
        struct UpsertingSameId {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedMeal>
            let picked: Meal
            let revised: Meal

            init() throws {
                let filled = try CachedMealCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                picked = filled.picked
                revised = Meal(
                    id: filled.written.id, eatenAt: Date(timeIntervalSince1970: 1_790_050_200),
                    eatenUtcOffsetSeconds: -14_400,
                    sentAt: Date(timeIntervalSince1970: 1_790_050_260),
                    sentTimeZone: try #require(TimeZone(identifier: "America/New_York")),
                    entry: .captured, photoIds: [UUID()])
            }

            @Test("行を増やさず、送った文章の ID も含めて値が替わること")
            func replaces() throws {
                try cache.upsert(revised)

                let saved = try cache.savedRecords()
                #expect(saved.count == 2)
                #expect(Set(saved) == [picked, revised])
            }
        }

        @Test("ID で消すと、その食事の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: written.id)

            #expect(try cache.savedRecords() == [picked])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らないタイムゾーンの行、知らない入口の行、送った文章の ID の無い文章の食事の行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedMeal>
        let readable: Meal

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = try CachedMealCacheTests.meal(id: UUID(), entry: .captured, photoIds: [])
            let unknownTimeZone = try CachedMealCacheTests.meal(
                id: UUID(), entry: .captured, photoIds: [])
            let unknownEntry = try CachedMealCacheTests.meal(
                id: UUID(), entry: .captured, photoIds: [])
            let writtenWithoutSentText = try CachedMealCacheTests.meal(
                id: UUID(), entry: .written(sentTextId: UUID()), photoIds: [])
            try cache.upsert(readable)
            try cache.upsert(unknownTimeZone)
            try cache.upsert(unknownEntry)
            try cache.upsert(writtenWithoutSentText)
            try #require(try CachedMeal.find(id: unknownTimeZone.id, in: context))
                .sentTimeZoneIdentifier = "Nowhere/Unknown"
            try #require(try CachedMeal.find(id: unknownEntry.id, in: context)).entry = "spoken"
            try #require(try CachedMeal.find(id: writtenWithoutSentText.id, in: context))
                .sentTextId = nil
            try context.save()
        }

        @Test("読めない行を飛ばし、読める食事だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
