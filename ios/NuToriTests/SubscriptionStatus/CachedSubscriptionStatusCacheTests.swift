import Foundation
import NuToriCore
import SwiftData
import Testing

@testable import NuTori

@Suite("サブスクリプションの状態のキャッシュの行")
struct CachedSubscriptionStatusCacheTests {
    static let periodEndsAt = Date(timeIntervalSince1970: 1_800_000_000)

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
    }

    @Suite("まだ何も書いていない行に、テストユーザーを書くとき")
    @MainActor
    struct WritingTestUser {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>
        let testUser: SubscriptionStatus

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            testUser = .testUser
        }

        @Test("同じ状態を読めること")
        func readsBackTestUser() throws {
            try cache.write(testUser)

            #expect(try cache.savedRecord() == testUser)
        }
    }

    @Suite("まだ何も書いていない行に、無料体験中で買っていない状態を書くとき")
    @MainActor
    struct WritingFreeTrial {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>
        let freeTrial: SubscriptionStatus

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            freeTrial = .regular(
                freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
                subscription: .none)
        }

        @Test("同じ状態を読めること")
        func readsBackFreeTrial() throws {
            try cache.write(freeTrial)

            #expect(try cache.savedRecord() == freeTrial)
        }
    }

    @Suite("まだ何も書いていない行に、作り直したアカウントで、猶予の無いサブスクリプション中の状態を書くとき")
    @MainActor
    struct WritingSubscribedWithoutGrace {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>
        let subscribedWithoutGrace: SubscriptionStatus

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            subscribedWithoutGrace = .regular(
                freeTrial: .usedByEarlierAccount,
                subscription: .subscribed(
                    plan: .monthly, periodEndsAt: CachedSubscriptionStatusCacheTests.periodEndsAt,
                    billingGrace: .none))
        }

        @Test("同じ状態を読めること")
        func readsBackSubscribedWithoutGrace() throws {
            try cache.write(subscribedWithoutGrace)

            #expect(try cache.savedRecord() == subscribedWithoutGrace)
        }
    }

    @Suite("まだ何も書いていない行に、猶予のあるサブスクリプション中の状態を書くとき")
    @MainActor
    struct WritingSubscribedWithGrace {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>
        let subscribedWithGrace: SubscriptionStatus

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            subscribedWithGrace = .regular(
                freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
                subscription: .subscribed(
                    plan: .yearly, periodEndsAt: CachedSubscriptionStatusCacheTests.periodEndsAt,
                    billingGrace: .granted(
                        endsAt: CachedSubscriptionStatusCacheTests.periodEndsAt.addingTimeInterval(
                            86_400))))
        }

        @Test("同じ状態を読めること")
        func readsBackSubscribedWithGrace() throws {
            try cache.write(subscribedWithGrace)

            #expect(try cache.savedRecord() == subscribedWithGrace)
        }
    }

    @Suite("サブスクリプション中の状態を書いたとき")
    @MainActor
    struct Written {
        let store: SwiftDataSyncStore
        let cache: SwiftDataSingleRecordCache<CachedSubscriptionStatus>
        let revised: SubscriptionStatus

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            cache = SwiftDataSingleRecordCache(context: store.container.mainContext)
            let subscribedWithGrace = SubscriptionStatus.regular(
                freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
                subscription: .subscribed(
                    plan: .yearly, periodEndsAt: CachedSubscriptionStatusCacheTests.periodEndsAt,
                    billingGrace: .granted(
                        endsAt: CachedSubscriptionStatusCacheTests.periodEndsAt.addingTimeInterval(
                            86_400))))
            try cache.write(subscribedWithGrace)
            try cache.context.save()
            revised = .regular(freeTrial: .usedByEarlierAccount, subscription: .none)
        }

        @Test("別の状態を書くと、行を増やさず、前の状態の値を残さずに替わること")
        func replaces() throws {
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
            try cache.write(
                .regular(
                    freeTrial: .usedByEarlierAccount,
                    subscription: .subscribed(
                        plan: .monthly,
                        periodEndsAt: CachedSubscriptionStatusCacheTests.periodEndsAt,
                        billingGrace: .none)))
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
