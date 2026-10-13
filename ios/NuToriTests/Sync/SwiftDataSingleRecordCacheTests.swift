import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// 行と記録の対応は、種類ごとのテスト（`Cached…CacheTests`）で確かめる。ここでは、保存の前に続けて読み書きしたときの adapter を確かめる
@Suite("SwiftData の、1件だけの記録のキャッシュ")
struct SwiftDataSingleRecordCacheTests {
    /// 置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func emptyCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataSingleRecordCache<CachedUsualWeighingTime>(
            context: store.container.mainContext)
        cache.context.autosaveEnabled = false
        return (store, cache)
    }

    @Suite("まだ何も保存していないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>
        let written: UsualWeighingTime

        init() throws {
            (store, cache) = try SwiftDataSingleRecordCacheTests.emptyCache()
            written = UsualWeighingTime(id: UUID(), minuteOfDay: 435)
        }

        @Test("保存の前に書いた値を、同じ保存の前に読めること")
        func readsUnsavedRecord() throws {
            try cache.write(written)

            #expect(try cache.read() == written)
        }
    }

    @Suite("まだ何も保存していなくて、保存の前に値を書いたとき")
    @MainActor
    struct WrittenBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>
        let latest: UsualWeighingTime

        init() throws {
            (store, cache) = try SwiftDataSingleRecordCacheTests.emptyCache()
            latest = UsualWeighingTime(id: UUID(), minuteOfDay: 450)
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))
        }

        @Test("もう一度書くと、行を増やさず、あとの値になること")
        func writesTwiceBeforeSaving() throws {
            try cache.write(latest)

            #expect(try cache.savedRecord() == latest)
            #expect(try cache.context.fetchCount(FetchDescriptor<CachedUsualWeighingTime>()) == 1)
        }

        @Test("書いた値も、空にできること")
        func clearsUnsavedRecord() throws {
            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }
    }

    @Suite("値を保存してあるとき")
    @MainActor
    struct Saved {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>

        init() throws {
            (store, cache) = try SwiftDataSingleRecordCacheTests.emptyCache()
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))
            try cache.context.save()
        }

        @Test("空にしたあと、同じ保存の前に読んでも無いこと")
        func readsNothingAfterClearing() throws {
            try cache.clear()

            #expect(try cache.read() == nil)
        }
    }

    @Suite("保存してある値を、保存の前に空にしたとき")
    @MainActor
    struct ClearedBeforeSaving {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>
        let again: UsualWeighingTime

        init() throws {
            (store, cache) = try SwiftDataSingleRecordCacheTests.emptyCache()
            again = UsualWeighingTime(id: UUID(), minuteOfDay: 450)
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))
            try cache.context.save()
            try cache.clear()
        }

        @Test("同じ保存の前に書き直すと、書いた値が残ること")
        func writesAfterClearing() throws {
            try cache.write(again)

            #expect(try cache.savedRecord() == again)
        }
    }
}
