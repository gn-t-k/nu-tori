import Foundation
import NuToriCore
import Testing

@Suite("メモリの、ID で引く記録のキャッシュ")
struct MemoryKeyedRecordCacheTests {
    @Suite("記録を2件足したとき")
    struct Filled {
        let cache: any KeyedRecordCache<WeightRecord, UUID>
        let kept: WeightRecord
        let revised: WeightRecord

        init() throws {
            cache = MemoryKeyedRecordCache<WeightRecord, UUID>(id: \.id)
            kept = try .manual(70.0, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
            revised = try .manual(71.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            try cache.upsert(kept)
            try cache.upsert(revised)
        }

        @Test("足した記録を全部読めること")
        func readsAll() throws {
            #expect(Set(try cache.all().map(\.id)) == [kept.id, revised.id])
        }

        @Test("同じ ID の記録を足すと、増えずに値が替わること")
        func upsertReplacesSameId() throws {
            let newer = WeightRecord(
                id: revised.id, kilograms: 73.0, instant: revised.instant,
                timeZone: revised.timeZone, inputSource: .manual, version: 2)

            try cache.upsert(newer)

            #expect(try cache.all().count == 2)
            #expect(try cache.all().first { $0.id == revised.id } == newer)
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
