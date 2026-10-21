import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("サブスクリプションの状態の同期の形")
struct SubscriptionStatusSyncingTests {
    static let periodEndsAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = SubscriptionStatusSyncing()
        let cache = MemorySingleRecordCache<SubscriptionStatus>()

        @Test("まだ届いていなければ、キャッシュに無いこと")
        func startsEmpty() throws {
            try syncing.apply([.unknown(kind: "note")], to: cache)

            #expect(cache.read() == nil)
        }

        @Test("無料体験中の状態が、最後の日を日付にしてキャッシュに入ること")
        func storesFreeTrial() throws {
            try syncing.apply(
                [
                    .subscriptionStatus(
                        .regular(freeTrial: .available(lastDay: "2026-11-19"), subscription: .none))
                ], to: cache)

            #expect(
                cache.read()
                    == .regular(
                        freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 19)),
                        subscription: .none))
        }

        @Test("サブスクリプション中の状態が、商品と期限と猶予の終わりのままキャッシュに入ること")
        func storesSubscribed() throws {
            let graceEndsAt = SubscriptionStatusSyncingTests.periodEndsAt.addingTimeInterval(86_400)
            try syncing.apply(
                [
                    .subscriptionStatus(
                        .regular(
                            freeTrial: .usedByEarlierAccount,
                            subscription: .subscribed(
                                plan: .yearly,
                                periodEndsAt: SubscriptionStatusSyncingTests.periodEndsAt,
                                billingGrace: .granted(endsAt: graceEndsAt))))
                ], to: cache)

            #expect(
                cache.read()
                    == .regular(
                        freeTrial: .usedByEarlierAccount,
                        subscription: .subscribed(
                            plan: .yearly,
                            periodEndsAt: SubscriptionStatusSyncingTests.periodEndsAt,
                            billingGrace: .granted(endsAt: graceEndsAt))))
        }

        @Test("続けて届いたら、最後に届いた状態にすること")
        func keepsLatest() throws {
            try syncing.apply(
                [
                    .subscriptionStatus(
                        .regular(freeTrial: .available(lastDay: "2026-11-19"), subscription: .none)),
                    .subscriptionStatus(.testUser),
                ], to: cache)

            #expect(cache.read() == .testUser)
        }

        @Test("最後の日が読めない状態は、キャッシュを変えないこと")
        func skipsUnreadableDay() throws {
            try syncing.apply([.subscriptionStatus(.testUser)], to: cache)

            try syncing.apply(
                [
                    .subscriptionStatus(
                        .regular(freeTrial: .available(lastDay: "11/19"), subscription: .none))
                ], to: cache)

            #expect(cache.read() == .testUser)
        }
    }

    @Suite("状態がキャッシュにあるとき")
    struct Cached {
        let syncing = SubscriptionStatusSyncing()
        let cache = MemorySingleRecordCache<SubscriptionStatus>()

        init() throws {
            try syncing.apply([.subscriptionStatus(.testUser)], to: cache)
        }

        @Test("状態の無い変更は、キャッシュの状態を変えないこと")
        func keepsWithoutChange() throws {
            try syncing.apply([.weightTrendAbsence], to: cache)

            #expect(cache.read() == .testUser)
        }

        @Test("空にすると、状態がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.read() == nil)
        }
    }
}
