import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("サブスクリプションの状態のキャッシュの行")
struct CachedSubscriptionStatusCacheTests {
    static let periodEndsAt = Date(timeIntervalSince1970: 1_800_000_000)

    static let statuses: [SubscriptionStatus] = [
        .testUser,
        .regular(
            freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
            subscription: .none),
        .regular(
            freeTrial: .usedByEarlierAccount,
            subscription: .subscribed(
                plan: .monthly, periodEndsAt: periodEndsAt, billingGrace: .none)),
        .regular(
            freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
            subscription: .subscribed(
                plan: .yearly, periodEndsAt: periodEndsAt,
                billingGrace: .granted(endsAt: periodEndsAt.addingTimeInterval(86_400)))),
    ]

    @Suite("まだ何も書いていないとき")
    @MainActor
    struct Empty {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
        }

        @Test("読むと無いこと")
        func readsNothing() throws {
            #expect(try cache.savedRecord() == nil)
        }

        @Test("テストユーザーを書くと、同じ状態を読めること")
        func readsBackTestUser() throws {
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[0])

            #expect(try cache.savedRecord() == CachedSubscriptionStatusCacheTests.statuses[0])
        }

        @Test("無料体験中で買っていない状態を書くと、同じ状態を読めること")
        func readsBackFreeTrial() throws {
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[1])

            #expect(try cache.savedRecord() == CachedSubscriptionStatusCacheTests.statuses[1])
        }

        @Test("作り直したアカウントで、猶予の無いサブスクリプション中の状態を書くと、同じ状態を読めること")
        func readsBackSubscribedWithoutGrace() throws {
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[2])

            #expect(try cache.savedRecord() == CachedSubscriptionStatusCacheTests.statuses[2])
        }

        @Test("猶予のあるサブスクリプション中の状態を書くと、同じ状態を読めること")
        func readsBackSubscribedWithGrace() throws {
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[3])

            #expect(try cache.savedRecord() == CachedSubscriptionStatusCacheTests.statuses[3])
        }
    }

    @Suite("サブスクリプション中の状態を書いたとき")
    @MainActor
    struct Written {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[3])
            try cache.context.save()
        }

        @Test("別の状態を書くと、行を増やさず、前の状態の値を残さずに替わること")
        func replaces() throws {
            let revised = SubscriptionStatus.regular(
                freeTrial: .usedByEarlierAccount, subscription: .none)

            try cache.write(revised)

            #expect(try cache.savedRecord() == revised)
            #expect(
                try cache.context.fetchCount(FetchDescriptor<CachedSubscriptionStatus>()) == 1)
        }

        @Test("空にすると、読んでも無いこと")
        func clears() throws {
            try cache.clear()

            #expect(try cache.savedRecord() == nil)
        }
    }

    @Suite("知らない商品の行があるとき")
    @MainActor
    struct UnknownPlan {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            try cache.write(CachedSubscriptionStatusCacheTests.statuses[2])
            let row = try #require(
                try cache.context.fetch(FetchDescriptor<CachedSubscriptionStatus>()).first)
            row.plan = "weekly"
            try cache.context.save()
        }

        @Test("読めない行として、無いと読むこと")
        func readsNothing() throws {
            #expect(try cache.savedRecord() == nil)
        }
    }
}
