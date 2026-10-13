import Foundation
import NuToriCore
import Testing

@Suite("メモリの、ID で引く記録のキャッシュ")
struct MemoryKeyedRecordCacheTests {
    /// 記録を2件足したキャッシュ
    static func filledCache() throws -> (
        cache: any KeyedRecordCache<WeightRecord, UUID>, kept: WeightRecord, revised: WeightRecord
    ) {
        let cache: any KeyedRecordCache<WeightRecord, UUID> =
            MemoryKeyedRecordCache<WeightRecord, UUID>(id: \.id)
        let kept = try WeightRecord.manual(
            70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
        let revised = try WeightRecord.manual(
            71.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
        try cache.upsert(kept)
        try cache.upsert(revised)
        return (cache, kept, revised)
    }

    @Suite("記録を2件足したとき")
    struct Filled {
        let cache: any KeyedRecordCache<WeightRecord, UUID>
        let kept: WeightRecord
        let revised: WeightRecord

        init() throws {
            (cache, kept, revised) = try MemoryKeyedRecordCacheTests.filledCache()
        }

        @Test("足した記録を全部読めること")
        func readsAll() throws {
            #expect(Set(try cache.all().map(\.id)) == [kept.id, revised.id])
        }

        @Suite("同じ ID の記録を足すとき")
        struct UpsertingSameId {
            let cache: any KeyedRecordCache<WeightRecord, UUID>
            let revised: WeightRecord
            let newer: WeightRecord

            init() throws {
                let filled = try MemoryKeyedRecordCacheTests.filledCache()
                cache = filled.cache
                revised = filled.revised
                newer = WeightRecord(
                    id: revised.id, kilograms: 73.0, instant: revised.instant,
                    timeZone: revised.timeZone, inputSource: .manual, version: 2)
            }

            @Test("増えずに値が替わること")
            func replaces() throws {
                try cache.upsert(newer)

                #expect(try cache.all().count == 2)
                #expect(try cache.all().first { $0.id == revised.id } == newer)
            }
        }

        @Test("ID で消すと、その記録だけが無くなること")
        func removesById() throws {
            try cache.remove(id: revised.id)

            #expect(try cache.all() == [kept])
        }

        @Test("キャッシュに無い ID を消しても、何も変わらないこと")
        func removingMissingIdIsSkipped() throws {
            try cache.remove(id: UUID())

            #expect(try cache.all().count == 2)
        }

        @Test("空にすると、1件も読めないこと")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.all().isEmpty)
        }
    }
}
