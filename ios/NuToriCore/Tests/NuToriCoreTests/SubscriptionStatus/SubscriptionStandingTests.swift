import Foundation
import NuToriCore
import Testing

@Suite("端末の今日でのサブスクリプションの状態")
struct SubscriptionStandingTests {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    static let lastDay = CalendarDay(year: 2026, month: 11, day: 19)
    static let inFreeTrial = SubscriptionStatus.regular(
        freeTrial: .available(lastDay: lastDay), subscription: .none)

    /// 東京のその日の正午
    static func noon(_ day: CalendarDay) -> Date {
        day.noon(in: tokyo)
    }

    @Suite("無料体験中のアカウント")
    struct FreeTrial {
        @Test("最後の日の2日前は、無料体験中で残りが3日であること")
        func threeDaysLeft() {
            let standing = SubscriptionStanding(
                status: SubscriptionStandingTests.inFreeTrial,
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 11, day: 17)),
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(
                standing == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 3)
            )
        }

        @Test("アカウントを作った日（最後の日の29日前）は、残りが30日であること")
        func firstDay() {
            let standing = SubscriptionStanding(
                status: SubscriptionStandingTests.inFreeTrial,
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 10, day: 21)),
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(
                standing
                    == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 30))
        }

        @Test("最後の日の終わりまでは、無料体験中で残りが1日であること")
        func lastDay() {
            let endOfLastDay = CalendarDay(year: 2026, month: 11, day: 20).noon(
                in: SubscriptionStandingTests.tokyo
            ).addingTimeInterval(-12 * 3600 - 1)

            let standing = SubscriptionStanding(
                status: SubscriptionStandingTests.inFreeTrial, now: endOfLastDay,
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(
                standing == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 1)
            )
        }

        @Test("最後の日の次の日は、サブスクリプション切れであること")
        func dayAfterLastDay() {
            let standing = SubscriptionStanding(
                status: SubscriptionStandingTests.inFreeTrial,
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 11, day: 20)),
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(standing == .expired)
            #expect(standing.isExpired)
        }

        @Test("タイムゾーンが変わると、同じ時刻でも今日が変わり、無料体験中かが変わること")
        func timeZoneChanged() {
            // 東京では 11月20日 5:00、ロサンゼルスでは 11月19日 12:00
            let now = CalendarDay(year: 2026, month: 11, day: 20).noon(
                in: SubscriptionStandingTests.tokyo
            ).addingTimeInterval(-7 * 3600)

            #expect(
                SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial, now: now,
                    timeZone: SubscriptionStandingTests.tokyo) == .expired)
            #expect(
                SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial, now: now,
                    timeZone: SubscriptionStandingTests.losAngeles)
                    == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 1))
        }
    }

    @Suite("サブスクリプションを買ったアカウント")
    struct Subscribed {
        static let periodEndsAt = SubscriptionStandingTests.noon(
            CalendarDay(year: 2026, month: 12, day: 25))

        static func status(billingGrace: SubscriptionStatus.BillingGrace) -> SubscriptionStatus {
            .regular(
                freeTrial: .available(lastDay: SubscriptionStandingTests.lastDay),
                subscription: .subscribed(
                    plan: .monthly, periodEndsAt: periodEndsAt, billingGrace: billingGrace))
        }

        @Test("無料体験中に買ったら、無料体験中でなくサブスクリプション中であること")
        func boughtInFreeTrial() {
            let standing = SubscriptionStanding(
                status: Self.status(billingGrace: .none),
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 11, day: 17)),
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(
                standing
                    == .subscribed(
                        plan: .monthly, periodEndsAt: Self.periodEndsAt, endsAt: Self.periodEndsAt))
            #expect(!standing.isExpired)
        }

        @Test("期限ちょうどは、サブスクリプション切れであること")
        func atPeriodEnd() {
            let standing = SubscriptionStanding(
                status: Self.status(billingGrace: .none), now: Self.periodEndsAt,
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(standing == .expired)
        }

        @Test("期限の直前は、サブスクリプション中であること")
        func justBeforePeriodEnd() {
            let standing = SubscriptionStanding(
                status: Self.status(billingGrace: .none),
                now: Self.periodEndsAt.addingTimeInterval(-1),
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(!standing.isExpired)
        }

        @Test("猶予があれば、期限を過ぎても猶予の終わりまではサブスクリプション中であること")
        func inBillingGrace() {
            let graceEndsAt = Self.periodEndsAt.addingTimeInterval(16 * 86_400)

            let inGrace = SubscriptionStanding(
                status: Self.status(billingGrace: .granted(endsAt: graceEndsAt)),
                now: Self.periodEndsAt.addingTimeInterval(86_400),
                timeZone: SubscriptionStandingTests.tokyo)
            let atGraceEnd = SubscriptionStanding(
                status: Self.status(billingGrace: .granted(endsAt: graceEndsAt)), now: graceEndsAt,
                timeZone: SubscriptionStandingTests.tokyo)

            #expect(
                inGrace
                    == .subscribed(
                        plan: .monthly, periodEndsAt: Self.periodEndsAt, endsAt: graceEndsAt))
            #expect(atGraceEnd == .expired)
        }
    }

    @Test("テストユーザーは、テストユーザーで、切れていないこと")
    func testUser() {
        let standing = SubscriptionStanding(
            status: .testUser,
            now: SubscriptionStandingTests.noon(CalendarDay(year: 2030, month: 1, day: 1)),
            timeZone: SubscriptionStandingTests.tokyo)

        #expect(standing == .testUser)
        #expect(!standing.isExpired)
    }

    @Test("作り直したアカウントは、買うまで最初からサブスクリプション切れであること")
    func recreatedAccount() {
        let standing = SubscriptionStanding(
            status: .regular(freeTrial: .usedByEarlierAccount, subscription: .none),
            now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 10, day: 21)),
            timeZone: SubscriptionStandingTests.tokyo)

        #expect(standing == .expired)
    }
}
