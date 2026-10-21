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
        @Test("あと3日の日より前は、知らせを出さないこと")
        func beforeThreeDaysLeft() {
            #expect(
                SubscriptionNoticeTests.notices(
                    SubscriptionNoticeTests.inFreeTrial,
                    today: CalendarDay(year: 2026, month: 11, day: 16)
                ).isEmpty)
        }

        @Test("あと3日の日は、その日に「あと 3 日」を出すこと")
        func threeDaysLeft() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.inFreeTrial, today: SubscriptionNoticeTests.threeDaysLeftDay
            )

            #expect(
                notices == [
                    SubscriptionNotice(
                        kind: .freeTrialEndsSoon(lastDay: SubscriptionNoticeTests.lastDay),
                        day: SubscriptionNoticeTests.threeDaysLeftDay)
                ])
        }

        @Test("最後の日は、あと3日の知らせも残し、その日に「今日まで」を出すこと")
        func lastDay() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.inFreeTrial, today: SubscriptionNoticeTests.lastDay)

            #expect(
                notices == [
                    SubscriptionNotice(
                        kind: .freeTrialEndsSoon(lastDay: SubscriptionNoticeTests.lastDay),
                        day: SubscriptionNoticeTests.threeDaysLeftDay),
                    SubscriptionNotice(
                        kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay),
                ])
        }

        @Test("最後の日の次の日は、その日に「無料体験が終わりました」を足すこと")
        func dayAfterLastDay() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.inFreeTrial, today: SubscriptionNoticeTests.dayAfterLastDay)

            #expect(
                notices.map(\.kind) == [
                    .freeTrialEndsSoon(lastDay: SubscriptionNoticeTests.lastDay), .freeTrialLastDay,
                    .freeTrialEnded,
                ])
            #expect(notices.last?.day == SubscriptionNoticeTests.dayAfterLastDay)
        }
    }

    @Suite("買ったとき")
    struct Bought {
        static let periodEndsAt = CalendarDay(year: 2026, month: 12, day: 25).noon(
            in: SubscriptionNoticeTests.tokyo)

        @Test("無料体験中に買ったら、過ぎた日の知らせも出さないこと")
        func boughtInFreeTrial() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: Self.periodEndsAt,
                    freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                today: SubscriptionNoticeTests.lastDay)

            #expect(notices.isEmpty)
        }

        @Test("切れたあとに買ったら、終わりました の知らせも出さないこと")
        func boughtAfterExpired() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: Self.periodEndsAt,
                    freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                today: CalendarDay(year: 2026, month: 11, day: 25))

            #expect(notices.isEmpty)
        }

        @Test("無料体験のあとに終わったら、終わりを含む日に「サブスクリプションが終わりました」を出すこと")
        func endedAfterFreeTrial() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: Self.periodEndsAt,
                    freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                today: CalendarDay(year: 2026, month: 12, day: 26))

            #expect(
                notices == [
                    SubscriptionNotice(
                        kind: .freeTrialEndsSoon(lastDay: SubscriptionNoticeTests.lastDay),
                        day: SubscriptionNoticeTests.threeDaysLeftDay),
                    SubscriptionNotice(
                        kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay),
                    SubscriptionNotice(
                        kind: .subscriptionEnded,
                        day: CalendarDay(year: 2026, month: 12, day: 25)),
                ])
        }

        @Test("無料体験中に返金で終わったら、無料体験が終わった日に「無料体験が終わりました」を出すこと")
        func endedInFreeTrial() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: SubscriptionNoticeTests.lastDay.noon(
                        in: SubscriptionNoticeTests.tokyo),
                    freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                today: CalendarDay(year: 2026, month: 11, day: 22))

            #expect(
                notices.last
                    == SubscriptionNotice(
                        kind: .freeTrialEnded, day: SubscriptionNoticeTests.dayAfterLastDay))
        }

        @Test("無料体験中に返金で終わっても、無料体験のあいだは、終わった知らせを出さないこと")
        func endedButStillInFreeTrial() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: CalendarDay(year: 2026, month: 11, day: 1).noon(
                        in: SubscriptionNoticeTests.tokyo),
                    freeTrial: .available(lastDay: SubscriptionNoticeTests.lastDay)),
                today: CalendarDay(year: 2026, month: 11, day: 10))

            #expect(notices.isEmpty)
        }
    }

    @Suite("作り直したアカウント")
    struct Recreated {
        @Test("買っていなければ、最初のサインインの日に「無料体験はありません」を出すこと")
        func noFreeTrial() {
            let notices = SubscriptionNoticeTests.notices(
                .regular(freeTrial: .usedByEarlierAccount, subscription: .none),
                today: CalendarDay(year: 2026, month: 11, day: 1))

            #expect(
                notices == [
                    SubscriptionNotice(
                        kind: .noFreeTrial, day: SubscriptionNoticeTests.firstSignInDay)
                ])
        }

        @Test("買ったら、無料体験はありません の知らせも出さないこと")
        func bought() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: CalendarDay(year: 2026, month: 12, day: 25).noon(
                        in: SubscriptionNoticeTests.tokyo),
                    freeTrial: .usedByEarlierAccount),
                today: CalendarDay(year: 2026, month: 11, day: 1))

            #expect(notices.isEmpty)
        }

        @Test("買ったあとに終わったら、終わりを含む日に「サブスクリプションが終わりました」だけを出すこと")
        func endedAfterBought() {
            let notices = SubscriptionNoticeTests.notices(
                SubscriptionNoticeTests.subscribed(
                    endingAt: CalendarDay(year: 2026, month: 12, day: 25).noon(
                        in: SubscriptionNoticeTests.tokyo),
                    freeTrial: .usedByEarlierAccount),
                today: CalendarDay(year: 2027, month: 1, day: 3))

            #expect(
                notices == [
                    SubscriptionNotice(
                        kind: .subscriptionEnded,
                        day: CalendarDay(year: 2026, month: 12, day: 25))
                ])
        }
    }

    @Test("テストユーザーには、どの知らせも出さないこと")
    func testUser() {
        #expect(
            SubscriptionNoticeTests.notices(
                .testUser, today: SubscriptionNoticeTests.dayAfterLastDay
            ).isEmpty)
    }

    @Suite("カードの文")
    struct Texts {
        static let ended =
            "体重の記録と、これまでの記録の見返しはこれまでどおりできます。写真から食事を記録すること、1日の目安の見直し、書いた文への返事には、サブスクリプションが必要です。"

        @Test("あと3日は、最後の日を入れた文と「サブスクリプションを見る」を持つこと")
        func threeDaysLeft() {
            let notice = SubscriptionNotice(
                kind: .freeTrialEndsSoon(lastDay: SubscriptionNoticeTests.lastDay),
                day: SubscriptionNoticeTests.threeDaysLeftDay)

            #expect(notice.title == "無料体験はあと 3 日")
            #expect(
                notice.body
                    == "11月19日で終わります。そのあとも体重の記録と、これまでの記録の見返しはできます。")
            #expect(notice.showsSubscriptionButton)
        }

        @Test("今日までは、明日からのことと「サブスクリプションを見る」を持つこと")
        func lastDay() {
            let notice = SubscriptionNotice(
                kind: .freeTrialLastDay, day: SubscriptionNoticeTests.lastDay)

            #expect(notice.title == "無料体験は今日まで")
            #expect(
                notice.body
                    == "明日から、撮って記録するにはサブスクリプションが必要です。体重の記録と見返しはそのままできます。")
            #expect(notice.showsSubscriptionButton)
        }

        @Test("無料体験が終わった・サブスクリプションが終わったは、同じ本文で、ボタンを持たないこと")
        func ended() {
            let freeTrialEnded = SubscriptionNotice(
                kind: .freeTrialEnded, day: SubscriptionNoticeTests.dayAfterLastDay)
            let subscriptionEnded = SubscriptionNotice(
                kind: .subscriptionEnded, day: SubscriptionNoticeTests.dayAfterLastDay)

            #expect(freeTrialEnded.title == "無料体験が終わりました")
            #expect(subscriptionEnded.title == "サブスクリプションが終わりました")
            #expect(freeTrialEnded.body == Self.ended)
            #expect(subscriptionEnded.body == Self.ended)
            #expect(!freeTrialEnded.showsSubscriptionButton)
            #expect(!subscriptionEnded.showsSubscriptionButton)
        }

        @Test("無料体験はありませんは、前に使った Apple ID のことを書き、ボタンを持たないこと")
        func noFreeTrial() {
            let notice = SubscriptionNotice(
                kind: .noFreeTrial, day: SubscriptionNoticeTests.firstSignInDay)

            #expect(notice.title == "無料体験はありません")
            #expect(
                notice.body
                    == "このアカウントは、前に無料体験を使った Apple ID で作られました。体重の記録と、これまでの記録の見返しはできます。写真から食事を記録すること、1日の目安の見直し、書いた文への返事には、サブスクリプションが必要です。"
            )
            #expect(!notice.showsSubscriptionButton)
        }
    }
}
