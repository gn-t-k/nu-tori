import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("送った文章のキャッシュの行")
struct CachedSentTextCacheTests {
    @Suite("送った文章を2件足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let breakfast: SentText
        let question: SentText

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            breakfast = SentText(
                id: UUID(), body: "朝ごはんに納豆ご飯と味噌汁",
                sentAt: Date(timeIntervalSince1970: 1_790_046_600),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
            question = SentText(
                id: UUID(), body: "たんぱく質は足りてる？\n今週の分で",
                sentAt: Date(timeIntervalSince1970: 1_790_050_200.75),
                timeZone: try #require(TimeZone(identifier: "America/New_York")))
            try cache.upsert(breakfast)
            try cache.upsert(question)
            try cache.context.save()
        }

        @Test("足した文章と同じ文章を読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [breakfast, question])
        }

        @Test("同じ ID の文章を足すと、行を増やさず値が替わること")
        func replacesSameId() throws {
            let revised = SentText(
                id: question.id, body: "脂質は足りてる？",
                sentAt: Date(timeIntervalSince1970: 1_790_053_800),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))

            try cache.upsert(revised)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [breakfast, revised])
        }

        @Test("ID で消すと、その文章の行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: question.id)

            #expect(try cache.savedRecords() == [breakfast])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らないタイムゾーンの行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedSentText>
        let readable: SentText

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            readable = SentText(
                id: UUID(), body: "朝ごはん", sentAt: Date(timeIntervalSince1970: 1_790_046_600),
                timeZone: tokyo)
            let unknownTimeZone = SentText(
                id: UUID(), body: "昼ごはん", sentAt: Date(timeIntervalSince1970: 1_790_064_600),
                timeZone: tokyo)
            try cache.upsert(readable)
            try cache.upsert(unknownTimeZone)
            try #require(try CachedSentText.find(id: unknownTimeZone.id, in: context))
                .timeZoneIdentifier = "Nowhere/Unknown"
            try context.save()
        }

        @Test("読めない行を飛ばし、読める文章だけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
