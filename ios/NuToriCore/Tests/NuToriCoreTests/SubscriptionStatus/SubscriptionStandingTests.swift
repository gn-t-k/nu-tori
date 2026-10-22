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
        @Suite("最後の日の2日前")
        struct ThreeDaysLeft {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial,
                    now: SubscriptionStandingTests.noon(
                        CalendarDay(year: 2026, month: 11, day: 17)),
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("無料体験中で残りが3日であること")
            func threeDaysLeft() {
                #expect(
                    standing
                        == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 3))
            }
        }

        @Suite("アカウントを作った日（最後の日の29日前）")
        struct FirstDay {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial,
                    now: SubscriptionStandingTests.noon(
                        CalendarDay(year: 2026, month: 10, day: 21)),
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("残りが30日であること")
            func firstDay() {
                #expect(
                    standing
                        == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 30)
                )
            }
        }

        @Suite("最後の日の終わり")
        struct EndOfLastDay {
            let standing: SubscriptionStanding

            init() {
                let endOfLastDay = CalendarDay(year: 2026, month: 11, day: 20).noon(
                    in: SubscriptionStandingTests.tokyo
                ).addingTimeInterval(-12 * 3600 - 1)
                standing = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial, now: endOfLastDay,
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("無料体験中で残りが1日であること")
            func lastDay() {
                #expect(
                    standing
                        == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 1))
            }
        }

        @Suite("最後の日の次の日")
        struct DayAfterLastDay {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial,
                    now: SubscriptionStandingTests.noon(
                        CalendarDay(year: 2026, month: 11, day: 20)),
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("サブスクリプション切れであること")
            func dayAfterLastDay() {
                #expect(standing == .expired)
                #expect(standing.isExpired)
            }
        }

        @Suite("同じ時刻で、タイムゾーンが変わったとき")
        struct TimeZoneChanged {
            let inTokyo: SubscriptionStanding
            let inLosAngeles: SubscriptionStanding

            init() {
                // 東京では 11月20日 5:00、ロサンゼルスでは 11月19日 12:00
                let now = CalendarDay(year: 2026, month: 11, day: 20).noon(
                    in: SubscriptionStandingTests.tokyo
                ).addingTimeInterval(-7 * 3600)
                inTokyo = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial, now: now,
                    timeZone: SubscriptionStandingTests.tokyo)
                inLosAngeles = SubscriptionStanding(
                    status: SubscriptionStandingTests.inFreeTrial, now: now,
                    timeZone: SubscriptionStandingTests.losAngeles)
            }

            @Test("今日が変わり、無料体験中かが変わること")
            func timeZoneChanged() {
                #expect(inTokyo == .expired)
                #expect(
                    inLosAngeles
                        == .freeTrial(lastDay: SubscriptionStandingTests.lastDay, remainingDays: 1))
            }
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

        @Suite("無料体験中に買ったとき")
        struct BoughtInFreeTrial {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: Subscribed.status(billingGrace: .none),
                    now: SubscriptionStandingTests.noon(
                        CalendarDay(year: 2026, month: 11, day: 17)),
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("無料体験中でなくサブスクリプション中であること")
            func boughtInFreeTrial() {
                #expect(
                    standing
                        == .subscribed(
                            plan: .monthly, periodEndsAt: Subscribed.periodEndsAt,
                            endsAt: Subscribed.periodEndsAt))
                #expect(!standing.isExpired)
            }
        }

        @Suite("期限ちょうど")
        struct AtPeriodEnd {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: Subscribed.status(billingGrace: .none), now: Subscribed.periodEndsAt,
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("サブスクリプション切れであること")
            func atPeriodEnd() {
                #expect(standing == .expired)
            }
        }

        @Suite("期限の直前")
        struct JustBeforePeriodEnd {
            let standing: SubscriptionStanding

            init() {
                standing = SubscriptionStanding(
                    status: Subscribed.status(billingGrace: .none),
                    now: Subscribed.periodEndsAt.addingTimeInterval(-1),
                    timeZone: SubscriptionStandingTests.tokyo)
            }

            @Test("サブスクリプション中であること")
            func justBeforePeriodEnd() {
                #expect(!standing.isExpired)
            }
        }

        @Suite("請求の猶予があるとき")
        struct InBillingGrace {
            static let graceEndsAt = Subscribed.periodEndsAt.addingTimeInterval(16 * 86_400)

            @Suite("期限を過ぎて、猶予の終わりより前")
            struct BeforeGraceEnd {
                let standing: SubscriptionStanding

                init() {
                    standing = SubscriptionStanding(
                        status: Subscribed.status(
                            billingGrace: .granted(endsAt: InBillingGrace.graceEndsAt)),
                        now: Subscribed.periodEndsAt.addingTimeInterval(86_400),
                        timeZone: SubscriptionStandingTests.tokyo)
                }

                @Test("サブスクリプション中で、猶予の終わりを終わりにすること")
                func beforeGraceEnd() {
                    #expect(
                        standing
                            == .subscribed(
                                plan: .monthly, periodEndsAt: Subscribed.periodEndsAt,
                                endsAt: InBillingGrace.graceEndsAt))
                }
            }

            @Suite("猶予の終わりちょうど")
            struct AtGraceEnd {
                let standing: SubscriptionStanding

                init() {
                    standing = SubscriptionStanding(
                        status: Subscribed.status(
                            billingGrace: .granted(endsAt: InBillingGrace.graceEndsAt)),
                        now: InBillingGrace.graceEndsAt,
                        timeZone: SubscriptionStandingTests.tokyo)
                }

                @Test("サブスクリプション切れであること")
                func atGraceEnd() {
                    #expect(standing == .expired)
                }
            }
        }
    }

    @Suite("テストユーザーのアカウント")
    struct TestUser {
        let standing: SubscriptionStanding

        init() {
            standing = SubscriptionStanding(
                status: .testUser,
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2030, month: 1, day: 1)),
                timeZone: SubscriptionStandingTests.tokyo)
        }

        @Test("テストユーザーで、切れていないこと")
        func testUser() {
            #expect(standing == .testUser)
            #expect(!standing.isExpired)
        }
    }

    @Suite("作り直したアカウント")
    struct Recreated {
        let standing: SubscriptionStanding

        init() {
            standing = SubscriptionStanding(
                status: .regular(freeTrial: .usedByEarlierAccount, subscription: .none),
                now: SubscriptionStandingTests.noon(CalendarDay(year: 2026, month: 10, day: 21)),
                timeZone: SubscriptionStandingTests.tokyo)
        }

        @Test("買うまで最初からサブスクリプション切れであること")
        func recreatedAccount() {
            #expect(standing == .expired)
        }
    }
}
