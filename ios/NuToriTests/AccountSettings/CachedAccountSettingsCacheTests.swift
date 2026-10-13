import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

/// アカウントの設定の行は、どの値でも読める（読めない行を持たない）
@Suite("アカウントの設定のキャッシュの行")
struct CachedAccountSettingsCacheTests {
    /// 設定を書いて保存してあるキャッシュ。置き場は、キャッシュを使うあいだ持っておく
    @MainActor static func writtenCache() throws -> (
        store: SwiftDataSyncStore, cache: SwiftDataSingleRecordCache<CachedAccountSettings>,
        settings: AccountSettings
    ) {
        let store = try SwiftDataSyncStore(inMemory: true)
        let cache = SwiftDataSingleRecordCache<CachedAccountSettings>(
            context: store.container.mainContext)
        let settings = AccountSettings(id: UUID(), sendsUsageData: true)
        try cache.write(settings)
        try cache.context.save()
        return (store, cache, settings)
    }

    @Suite("まだ何も書いていないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedAccountSettings>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
        }

        @Test("読むと無いこと")
        func readsNothing() throws {
            #expect(try cache.savedRecord() == nil)
        }
    }

    @Suite("設定を書いたとき")
    @MainActor
    struct Written {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedAccountSettings>
        let settings: AccountSettings

        init() throws {
            (store, cache, settings) = try CachedAccountSettingsCacheTests.writtenCache()
        }

        @Test("書いた設定と同じ設定を読めること")
        func readsBackSameRecord() throws {
            #expect(try cache.savedRecord() == settings)
        }

        @Suite("別の設定を書くとき")
        @MainActor
        struct WritingAnother {
            let store: SwiftDataSyncStore
            let cache: SwiftDataSingleRecordCache<CachedAccountSettings>
            let revised: AccountSettings

            init() throws {
                (store, cache, _) = try CachedAccountSettingsCacheTests.writtenCache()
                revised = AccountSettings(id: UUID(), sendsUsageData: false)
            }

            @Test("行を増やさず値が替わること")
            func replaces() throws {
                try cache.write(revised)

                #expect(try cache.savedRecord() == revised)
                #expect(
                    try cache.context.fetchCount(FetchDescriptor<CachedAccountSettings>()) == 1)
            }
        }

        @Test("空にすると、読んでも無いこと")
        func clears() throws {
            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }
    }
}
