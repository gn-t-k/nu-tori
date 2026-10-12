import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// いつもの時刻の行は、どの値でも読める（読めない行を持たない）
@Suite("いつもの時刻のキャッシュの行")
struct CachedUsualWeighingTimeCacheTests {
    @Suite("まだ何も書いていないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
        }

        @Test("読むと無いこと")
        func readsNothing() throws {
            #expect(try cache.savedRecord() == nil)
        }
    }

    @Suite("いつもの時刻を書いたとき")
    @MainActor
    struct Written {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>
        let usualWeighingTime: UsualWeighingTime

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            usualWeighingTime = UsualWeighingTime(id: UUID(), minuteOfDay: 435)
            try cache.write(usualWeighingTime)
            try cache.context.save()
        }

        @Test("書いた時刻と同じ時刻を読めること")
        func readsBackSameRecord() throws {
            #expect(try cache.savedRecord() == usualWeighingTime)
        }

        @Test("別の時刻を書くと、行を増やさず値が替わること")
        func replaces() throws {
            let revised = UsualWeighingTime(id: UUID(), minuteOfDay: 450)

            try cache.write(revised)

            #expect(try cache.savedRecord() == revised)
            #expect(try cache.context.fetchCount(FetchDescriptor<CachedUsualWeighingTime>()) == 1)
        }

        @Test("空にすると、読んでも無いこと")
        func clears() throws {
            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }
    }
}
