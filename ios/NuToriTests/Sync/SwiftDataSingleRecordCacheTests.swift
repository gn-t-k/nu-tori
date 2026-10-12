import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// 行と記録の対応は、種類ごとのテスト（`Cached…CacheTests`）で確かめる。ここでは、保存の前に続けて読み書きしたときの adapter を確かめる
@Suite("SwiftData の、1件だけの記録のキャッシュ")
struct SwiftDataSingleRecordCacheTests {
    @Suite("まだ何も保存していないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedUsualWeighingTime>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            cache.context.autosaveEnabled = false
        }

        @Test("保存の前に書いた値を、同じ保存の前に読めること")
        func readsUnsavedRecord() throws {
            let written = UsualWeighingTime(id: UUID(), minuteOfDay: 435)

            try cache.write(written)

            #expect(try cache.read() == written)
        }

        @Test("保存の前に2回書くと、行を増やさず、あとの値になること")
        func writesTwiceBeforeSaving() throws {
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))
            let latest = UsualWeighingTime(id: UUID(), minuteOfDay: 450)

            try cache.write(latest)

            #expect(try cache.savedRecord() == latest)
            #expect(try cache.context.fetchCount(FetchDescriptor<CachedUsualWeighingTime>()) == 1)
        }

        @Test("保存の前に書いた値も、空にできること")
        func clearsUnsavedRecord() throws {
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))

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
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            cache.context.autosaveEnabled = false
            try cache.write(UsualWeighingTime(id: UUID(), minuteOfDay: 435))
            try cache.context.save()
        }

        @Test("空にしたあと、同じ保存の前に読んでも無いこと")
        func readsNothingAfterClearing() throws {
            try cache.clear()

            #expect(try cache.read() == nil)
        }

        @Test("空にしてから、同じ保存の前に書き直すと、書いた値が残ること")
        func writesAfterClearing() throws {
            let again = UsualWeighingTime(id: UUID(), minuteOfDay: 450)
            try cache.clear()

            try cache.write(again)

            #expect(try cache.savedRecord() == again)
        }
    }
}
