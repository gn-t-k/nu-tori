import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// 返事の行は、どの値でも読める（読めない行を持たない）
@Suite("返事のキャッシュの行")
struct CachedAiUtteranceCacheTests {
    /// 食事を指し示す返事と、指し示さない返事を保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func filledCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataKeyedRecordCache<CachedAiUtterance>,
        pointing: AiUtterance, plain: AiUtterance
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataKeyedRecordCache<CachedAiUtterance>(
            context: store.container.mainContext)
        // 食事の並びは ID の順と逆にして、並び順を保つことを確かめる
        let pointing = AiUtterance(
            id: UUID(), body: "たんぱく質が多かったのは、この2つの食事です。", sentTextId: UUID(),
            mealIds: [
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f2")),
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")),
            ])
        let plain = AiUtterance(
            id: UUID(), body: "今週は目安に届いています。", sentTextId: UUID(), mealIds: [])
        try cache.upsert(pointing)
        try cache.upsert(plain)
        try cache.context.save()
        return (store, cache, pointing, plain)
    }

    @Suite("食事を指し示す返事と、指し示さない返事を足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedAiUtterance>
        let pointing: AiUtterance
        let plain: AiUtterance

        init() throws {
            (store, cache, pointing, plain) = try CachedAiUtteranceCacheTests.filledCache()
        }

        @Test("足した返事と同じ返事を、指し示す食事の並び順を保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [pointing, plain])
        }

        @Suite("同じ ID の返事を足すとき")
        @MainActor
        struct UpsertingSameId {
            let store: SwiftDataSyncStore
            let cache: SwiftDataKeyedRecordCache<CachedAiUtterance>
            let plain: AiUtterance
            let revised: AiUtterance

            init() throws {
                let filled = try CachedAiUtteranceCacheTests.filledCache()
                store = filled.store
                cache = filled.cache
                plain = filled.plain
                revised = AiUtterance(
                    id: filled.pointing.id, body: "脂質が多かったのは、この食事です。",
                    sentTextId: UUID(), mealIds: [UUID()])
            }

            @Test("行を増やさず値が替わること")
            func replaces() throws {
                try cache.upsert(revised)

                let saved = try cache.savedRecords()
                #expect(saved.count == 2)
                #expect(Set(saved) == [revised, plain])
            }
        }

        @Test("ID で消すと、その返事の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: pointing.id)

            #expect(try cache.savedRecords() == [plain])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }
}
