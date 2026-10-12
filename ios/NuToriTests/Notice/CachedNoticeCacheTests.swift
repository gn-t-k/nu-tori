import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("知らせのキャッシュの行")
struct CachedNoticeCacheTests {
    static func notice(day: Int, response: Notice.Response?) throws -> Notice {
        let targetDay = CalendarDay(year: 2026, month: 9, day: day)
        return Notice(
            id: Notice.id(kind: .missedWeightRecord, targetDay: targetDay),
            kind: .missedWeightRecord, issuedAt: Date(timeIntervalSince1970: 1_790_028_900),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), targetDay: targetDay,
            response: response)
    }

    @Suite("答えていない知らせと、答えた知らせを足したとき")
    @MainActor
    struct Filled {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedNotice>
        let unanswered: Notice
        let answered: Notice

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataKeyedRecordCache(context: store.container.mainContext)
            unanswered = try CachedNoticeCacheTests.notice(day: 22, response: nil)
            answered = try CachedNoticeCacheTests.notice(
                day: 21,
                response: Notice.Response(
                    respondedAt: Date(timeIntervalSince1970: 1_790_029_800),
                    timeZone: try #require(TimeZone(identifier: "America/New_York"))))
            try cache.upsert(unanswered)
            try cache.upsert(answered)
            try cache.context.save()
        }

        @Test("足した知らせと同じ知らせを、答えを保って読めること")
        func readsBackSameRecords() throws {
            #expect(Set(try cache.savedRecords()) == [unanswered, answered])
        }

        @Test("同じ ID の答えた知らせを足すと、行を増やさず、答えた形に替わること")
        func replacesWithResponse() throws {
            let responded = try CachedNoticeCacheTests.notice(
                day: 22,
                response: Notice.Response(
                    respondedAt: Date(timeIntervalSince1970: 1_790_030_000),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))

            try cache.upsert(responded)

            let saved = try cache.savedRecords()
            #expect(saved.count == 2)
            #expect(Set(saved) == [responded, answered])
        }

        @Test("同じ ID の答えていない知らせを足すと、答えが無くなること")
        func replacesWithoutResponse() throws {
            let withdrawn = try CachedNoticeCacheTests.notice(day: 21, response: nil)

            try cache.upsert(withdrawn)

            #expect(Set(try cache.savedRecords()) == [unanswered, withdrawn])
        }

        @Test("ID で消すと、その知らせの行だけが無くなること")
        func removesById() throws {
            try cache.remove(id: unanswered.id)

            #expect(try cache.savedRecords() == [answered])
        }

        @Test("すべて消すと、行が無くなること")
        func removesAll() throws {
            try cache.removeAll()

            #expect(try cache.savedRecords().isEmpty)
        }
    }

    @Suite("知らない種類・知らないタイムゾーン・読めない日付・答えのタイムゾーンの無い行があるとき")
    @MainActor
    struct Unreadable {
        let store: SwiftDataSyncStore
        let cache: SwiftDataKeyedRecordCache<CachedNotice>
        let readable: Notice

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let context = store.container.mainContext
            cache = SwiftDataKeyedRecordCache(context: context)
            readable = try CachedNoticeCacheTests.notice(day: 20, response: nil)
            let unknownKind = try CachedNoticeCacheTests.notice(day: 21, response: nil)
            let unknownTimeZone = try CachedNoticeCacheTests.notice(day: 22, response: nil)
            let unreadableDay = try CachedNoticeCacheTests.notice(day: 23, response: nil)
            let responseWithoutTimeZone = try CachedNoticeCacheTests.notice(
                day: 24,
                response: Notice.Response(
                    respondedAt: Date(timeIntervalSince1970: 1_790_029_800),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
            for notice in [
                readable, unknownKind, unknownTimeZone, unreadableDay, responseWithoutTimeZone,
            ] {
                try cache.upsert(notice)
            }
            try #require(try CachedNotice.find(id: unknownKind.id, in: context)).kind =
                "missed-meal-record"
            try #require(try CachedNotice.find(id: unknownTimeZone.id, in: context))
                .timeZoneIdentifier = "Nowhere/Unknown"
            try #require(try CachedNotice.find(id: unreadableDay.id, in: context)).targetDay =
                "2026/09/23"
            try #require(try CachedNotice.find(id: responseWithoutTimeZone.id, in: context))
                .responseTimeZoneIdentifier = nil
            try context.save()
        }

        @Test("読めない行を飛ばし、読める知らせだけを読むこと")
        func skipsUnreadableRows() throws {
            #expect(try cache.savedRecords() == [readable])
        }
    }
}
