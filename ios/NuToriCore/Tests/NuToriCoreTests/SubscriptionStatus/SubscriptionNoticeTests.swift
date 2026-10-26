import Foundation
import NuToriCore
import Testing

@Suite("サブスクリプションの知らせ")
struct SubscriptionNoticeTests {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let firstSignInDay = CalendarDay(year: 2026, month: 10, day: 21)
    static let lastDay = CalendarDay(year: 2026, month: 11, day: 19)
    static let threeDaysLeftDay = CalendarDay(year: 2026, month: 11, day: 17)
    static let dayAfterLastDay = CalendarDay(year: 2026, month: 11, day: 20)
    static let inFreeTrial = SubscriptionStatus.regular(
        freeTrial: .available(lastDay: lastDay), subscription: .none)

    static func notices(_ status: SubscriptionStatus, today: CalendarDay) -> [SubscriptionNotice] {
        SubscriptionNotice.notices(
            status: status, now: today.noon(in: tokyo), timeZone: tokyo,
            firstSignInDay: firstSignInDay)
    }

    static func subscribed(endingAt periodEndsAt: Date, freeTrial: SubscriptionStatus.FreeTrial)
        -> SubscriptionStatus
    {
        .regular(
            freeTrial: freeTrial,
            subscription: .subscribed(
                plan: .monthly, periodEndsAt: periodEndsAt, billingGrace: .none))
    }

    @Suite("無料体験中で、買っていないとき")
    struct FreeTrial {
        @Suite("あと3日の日より前")
        struct BeforeThreeDaysLeft {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.inFreeTrial,
                    today: CalendarDay(year: 2026, month: 11, day: 16))
            }

            @Test("知らせを出さないこと")
            func noNotice() {
                #expect(notices.isEmpty)
            }
        }

        @Suite("あと3日の日")
        struct ThreeDaysLeft {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.inFreeTrial,
                    today: SubscriptionNoticeTests.threeDaysLeftDay)
            }

            @Test("その日に「あと 3 日」を出すこと")
            func threeDaysLeft() {
                #expect(
                    notices == [
                        SubscriptionNotice(
                            kind: .freeTrialEndsSoon,
                            day: SubscriptionNoticeTests.threeDaysLeftDay)
                    ])
            }
        }

        @Suite("最後の日")
        struct LastDay {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.inFreeTrial, today: SubscriptionNoticeTests.lastDay)
            }

            @Test("あと3日の知らせも残し、その日に「今日まで」を出すこと")
            func lastDay() {
                #expect(
                    notices == [
                        SubscriptionNotice(
                            kind: .freeTrialEndsSoon,
                            day: SubscriptionNoticeTests.threeDaysLeftDay),
                        SubscriptionNotice(
                            kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay),
                    ])
            }
        }

        @Suite("最後の日の次の日")
        struct DayAfterLastDay {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.inFreeTrial,
                    today: SubscriptionNoticeTests.dayAfterLastDay)
            }

            @Test("その日に「無料体験が終わりました」を足すこと")
            func dayAfterLastDay() {
                #expect(
                    notices.map(\.kind) == [
                        .freeTrialEndsSoon,
                        .freeTrialLastDay, .freeTrialEnded,
                    ])
                #expect(notices.last?.day == SubscriptionNoticeTests.dayAfterLastDay)
            }
        }
    }

    @Suite("買ったとき")
    struct Bought {
        static let periodEndsAt = CalendarDay(year: 2026, month: 12, day: 25).noon(
            in: SubscriptionNoticeTests.tokyo)

        @Suite("無料体験中に買ったとき")
        struct InFreeTrial {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: Bought.periodEndsAt,
                        freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                    today: SubscriptionNoticeTests.lastDay)
            }

            @Test("過ぎた日の知らせも出さないこと")
            func boughtInFreeTrial() {
                #expect(notices.isEmpty)
            }
        }

        @Suite("切れたあとに買ったとき")
        struct AfterExpired {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: Bought.periodEndsAt,
                        freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                    today: CalendarDay(year: 2026, month: 11, day: 25))
            }

            @Test("終わりました の知らせも出さないこと")
            func boughtAfterExpired() {
                #expect(notices.isEmpty)
            }
        }

        @Suite("無料体験のあとに終わったとき")
        struct EndedAfterFreeTrial {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: Bought.periodEndsAt,
                        freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                    today: CalendarDay(year: 2026, month: 12, day: 26))
            }

            @Test("終わりを含む日に「サブスクリプションが終わりました」を出すこと")
            func endedAfterFreeTrial() {
                #expect(
                    notices == [
                        SubscriptionNotice(
                            kind: .freeTrialEndsSoon,
                            day: SubscriptionNoticeTests.threeDaysLeftDay),
                        SubscriptionNotice(
                            kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay),
                        SubscriptionNotice(
                            kind: .subscriptionEnded,
                            day: CalendarDay(year: 2026, month: 12, day: 25)),
                    ])
            }
        }

        @Suite("無料体験中に返金で終わり、無料体験も終わったとき")
        struct EndedInFreeTrial {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: SubscriptionNoticeTests.lastDay.noon(
                            in: SubscriptionNoticeTests.tokyo),
                        freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                    today: CalendarDay(year: 2026, month: 11, day: 22))
            }

            @Test("無料体験が終わった日に「無料体験が終わりました」を出すこと")
            func endedInFreeTrial() {
                #expect(
                    notices.last
                        == SubscriptionNotice(
                            kind: .freeTrialEnded, day: SubscriptionNoticeTests.dayAfterLastDay))
            }
        }

        @Suite("無料体験中に返金で終わり、まだ無料体験のあいだのとき")
        struct EndedButStillInFreeTrial {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: CalendarDay(year: 2026, month: 11, day: 1).noon(
                            in: SubscriptionNoticeTests.tokyo),
                        freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                    today: CalendarDay(year: 2026, month: 11, day: 10))
            }

            @Test("終わった知らせを出さないこと")
            func endedButStillInFreeTrial() {
                #expect(notices.isEmpty)
            }
        }
    }

    @Suite("作り直したアカウント")
    struct Recreated {
        @Suite("買っていないとき")
        struct NotBought {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    .regular(freeTrial: .usedByEarlierAccount, subscription: .none),
                    today: CalendarDay(year: 2026, month: 11, day: 1))
            }

            @Test("最初のサインインの日に「無料体験はありません」を出すこと")
            func noFreeTrial() {
                #expect(
                    notices == [
                        SubscriptionNotice(
                            kind: .noFreeTrial, day: SubscriptionNoticeTests.firstSignInDay)
                    ])
            }
        }

        @Suite("買ったとき")
        struct Bought {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: CalendarDay(year: 2026, month: 12, day: 25).noon(
                            in: SubscriptionNoticeTests.tokyo),
                        freeTrial: .usedByEarlierAccount),
                    today: CalendarDay(year: 2026, month: 11, day: 1))
            }

            @Test("無料体験はありません の知らせも出さないこと")
            func bought() {
                #expect(notices.isEmpty)
            }
        }

        @Suite("買ったあとに終わったとき")
        struct EndedAfterBought {
            let notices: [SubscriptionNotice]

            init() {
                notices = SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.subscribed(
                        endingAt: CalendarDay(year: 2026, month: 12, day: 25).noon(
                            in: SubscriptionNoticeTests.tokyo),
                        freeTrial: .usedByEarlierAccount),
                    today: CalendarDay(year: 2027, month: 1, day: 3))
            }

            @Test("終わりを含む日に「サブスクリプションが終わりました」だけを出すこと")
            func endedAfterBought() {
                #expect(
                    notices == [
                        SubscriptionNotice(
                            kind: .subscriptionEnded,
                            day: CalendarDay(year: 2026, month: 12, day: 25))
                    ])
            }
        }
    }

    @Suite("テストユーザーのとき")
    struct TestUser {
        let notices: [SubscriptionNotice]

        init() {
            notices = SubscriptionNoticeTests.notices(
                .testUser, today: SubscriptionNoticeTests.dayAfterLastDay)
        }

        @Test("どの知らせも出さないこと")
        func testUser() {
            #expect(notices.isEmpty)
        }
    }

    @Suite("カードの文")
    struct Texts {
        static let ended =
            "体重の記録と、これまでの記録の見返しはこれまでどおりできます。写真から食事を記録すること、1日の目安の見直し、書いた文への返事には、サブスクリプションが必要です。"

        @Suite("あと3日")
        struct ThreeDaysLeft {
            let notice: SubscriptionNotice

            init() {
                notice = SubscriptionNotice(
                    kind: .freeTrialEndsSoon,
                    day: SubscriptionNoticeTests.threeDaysLeftDay)
            }

            @Test("無料体験のあともできることと「サブスクリプションを見る」を持つこと")
            func threeDaysLeft() {
                #expect(notice.title == "無料体験はあと 3 日")
                #expect(notice.body == "そのあとも体重の記録と、これまでの記録の見返しはできます。")
                #expect(notice.showsSubscriptionButton)
            }
        }

        @Suite("今日まで")
        struct LastDay {
            let notice: SubscriptionNotice

            init() {
                notice = SubscriptionNotice(
                    kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay)
            }

            @Test("明日からのことと「サブスクリプションを見る」を持つこと")
            func lastDay() {
                #expect(notice.title == "無料体験は今日まで")
                #expect(
                    notice.body
                        == "明日から、撮って記録するにはサブスクリプションが必要です。体重の記録と見返しはそのままできます。")
                #expect(notice.showsSubscriptionButton)
            }
        }

        @Suite("無料体験が終わった・サブスクリプションが終わった")
        struct Ended {
            let freeTrialEnded: SubscriptionNotice
            let subscriptionEnded: SubscriptionNotice

            init() {
                freeTrialEnded = SubscriptionNotice(
                    kind: .freeTrialEnded, day: SubscriptionNoticeTests.dayAfterLastDay)
                subscriptionEnded = SubscriptionNotice(
                    kind: .subscriptionEnded, day: SubscriptionNoticeTests.dayAfterLastDay)
            }

            @Test("同じ本文で、ボタンを持たないこと")
            func ended() {
                #expect(freeTrialEnded.title == "無料体験が終わりました")
                #expect(subscriptionEnded.title == "サブスクリプションが終わりました")
                #expect(freeTrialEnded.body == Texts.ended)
                #expect(subscriptionEnded.body == Texts.ended)
                #expect(!freeTrialEnded.showsSubscriptionButton)
                #expect(!subscriptionEnded.showsSubscriptionButton)
            }
        }

        @Suite("無料体験はありません")
        struct NoFreeTrial {
            let notice: SubscriptionNotice

            init() {
                notice = SubscriptionNotice(
                    kind: .noFreeTrial, day: SubscriptionNoticeTests.firstSignInDay)
            }

            @Test("前に使った Apple ID のことを書き、ボタンを持たないこと")
            func noFreeTrial() {
                #expect(notice.title == "無料体験はありません")
                #expect(
                    notice.body
                        == "このアカウントは、前に無料体験を使った Apple ID で作られました。体重の記録と、これまでの記録の見返しはできます。写真から食事を記録すること、1日の目安の見直し、書いた文への返事には、サブスクリプションが必要です。"
                )
                #expect(!notice.showsSubscriptionButton)
            }
        }
    }
}
