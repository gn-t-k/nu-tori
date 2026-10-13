import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("体重記録のキャッシュの行")
struct CachedWeightRecordCacheTests {
    /// 手で記録したものと、取り込んだものを保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedWeightRecord>,
        manual: WeightRecord, imported: WeightRecord
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedWeightRecord>(
            context: store.container.mainContext)
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let manual = WeightRecord(
            id: UUID(), kilograms: 70.4, instant: Date(timeIntervalSince1970: 1_790_028_720),
            timeZone: tokyo, inputSource: .manual, version: 1)
        let imported = WeightRecord(
            id: UUID(), kilograms: 70.15,
            instant: Date(timeIntervalSince1970: 1_790_115_120.5), timeZone: tokyo,
            inputSource: .imported(
                .init(
                    appName: "体組成計", bundleId: "com.example.scale",
                    healthKitSampleId: UUID(),
                    bodyFat: .init(percentage: 21.5, healthKitSampleId: UUID()))),
            version: 3)
        try cache.upsert(manual)
        try cache.upsert(imported)
        try cache.context.save()
        return (store, cache, manual, imported)
    }

    @Suite("手で記録したものと、取り込んだものを足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedWeightRecord>
        let manual: WeightRecord
        let imported: WeightRecord

        init() throws {
            (store, cache, manual, imported) = try CachedWeightRecordCacheTests.filledCache()
        }

        @Test("足した記録と同じ記録を読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [manual, imported])
        }

        @Suite("同じ ID の記録を足すとき")
        @MainActor
        struct UpsertingSameId {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedWeightRecord>
            let manual: WeightRecord
            let revised: WeightRecord

            init() throws {
                let filled = try CachedWeightRecordCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                manual = filled.manual
                revised = WeightRecord(
                    id: filled.imported.id, kilograms: 69.8,
                    instant: Date(timeIntervalSince1970: 1_790_118_000),
                    timeZone: try #require(TimeZone(identifier: "America/New_York")),
                    inputSource: .manual, version: 4)
            }

            @Test("行を増やさず、取り込みの出どころも含めて値が替わること")
            func replaces() throws {
                try cache.upsert(revised)

                let saved = try cache.savedRecords()
                #expect(saved.count == 2)
                #expect(Set(saved) == [manual, revised])
            }
        }

        @Test("ID で消すと、その記録の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: imported.id)

            #expect(try cache.savedRecords() == [manual])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らないタイムゾーンの行と、取り込みの出どころを読めない行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedWeightRecord>
        let readable: WeightRecord

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            readable = WeightRecord(
                id: UUID(), kilograms: 70.4, instant: Date(timeIntervalSince1970: 1_790_028_720),
                timeZone: tokyo, inputSource: .manual, version: 1)
            let unknownTimeZone = WeightRecord(
                id: UUID(), kilograms: 70.2, instant: Date(timeIntervalSince1970: 1_790_115_120),
                timeZone: tokyo, inputSource: .manual, version: 1)
            let unreadableSource = WeightRecord(
                id: UUID(), kilograms: 70.0, instant: Date(timeIntervalSince1970: 1_790_201_520),
                timeZone: tokyo, inputSource: .manual, version: 1)
            try cache.upsert(readable)
            try cache.upsert(unknownTimeZone)
            try cache.upsert(unreadableSource)
            try #require(try CachedWeightRecord.find(id: unknownTimeZone.id, in: context))
                .timeZoneIdentifier = "Nowhere/Unknown"
            try #require(try CachedWeightRecord.find(id: unreadableSource.id, in: context))
                .importedJSON = Data("{}".utf8)
            try context.save()
        }

        @Test("読めない行を飛ばし、読める記録だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
