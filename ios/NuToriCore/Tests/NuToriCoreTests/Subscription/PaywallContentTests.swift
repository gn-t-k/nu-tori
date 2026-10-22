import Foundation
import NuToriCore
import Testing

@Suite("課金画面の宣伝の部分とまとめ")
struct PaywallContentTests {
    @Suite("無料体験中のとき")
    struct FreeTrial {
        let content: PaywallContent?

        init() {
            content = PaywallContent(
                standing: .freeTrial(
                    lastDay: CalendarDay(year: 2026, month: 10, day: 30), remainingDays: 10),
                today: CalendarDay(year: 2026, month: 10, day: 21))
        }

        @Test("撮るだけで目安が合っていくことを見出しにすること")
        func headline() throws {
            #expect(try #require(content).headline == "撮るだけで、1日の目安が体に合っていく")
        }

        @Test("支払いが今日から始まり、無料体験の残りの日数がなくなると書くこと")
        func paymentStart() throws {
            #expect(try #require(content).paymentStart == "今日から。無料体験の残り 10 日はなくなります")
        }

        @Test("自動で更新することを書くこと")
        func renewal() {
            #expect(PaywallContent.renewal == "解約しない限り、自動で更新します。")
        }

        @Test("月額と年額の更新の間隔と、次の更新日を書くこと")
        func renewalSchedule() throws {
            #expect(
                try #require(content).renewalSchedule == [
                    "月額を選んだ場合: 1か月ごと（次は11月21日）",
                    "年額を選んだ場合: 1年ごと（次は2027年10月21日）",
                ])
        }
    }

    @Suite("サブスクリプション切れのとき")
    struct Expired {
        let content: PaywallContent?

        init() {
            content = PaywallContent(
                standing: .expired, today: CalendarDay(year: 2026, month: 10, day: 21))
        }

        @Test("撮って記録するにはサブスクリプションが必要なことを見出しにすること")
        func headline() throws {
            #expect(try #require(content).headline == "撮って記録するには、サブスクリプションが必要です")
        }

        @Test("支払いが今日から始まると書くこと")
        func paymentStart() throws {
            #expect(try #require(content).paymentStart == "今日から")
        }

        @Test("月額と年額の更新の間隔と、次の更新日を書くこと")
        func renewalSchedule() throws {
            #expect(
                try #require(content).renewalSchedule == [
                    "月額を選んだ場合: 1か月ごと（次は11月21日）",
                    "年額を選んだ場合: 1年ごと（次は2027年10月21日）",
                ])
        }
    }

    @Suite("次の月に同じ日が無いとき")
    struct MonthEnd {
        @Test("月額の次の更新日を、次の月の終わりの日にすること")
        func renewal() throws {
            let content = PaywallContent(
                standing: .expired, today: CalendarDay(year: 2027, month: 1, day: 31))

            #expect(
                try #require(content).renewalSchedule == [
                    "月額を選んだ場合: 1か月ごと（次は2月28日）",
                    "年額を選んだ場合: 1年ごと（次は2028年1月31日）",
                ])
        }
    }

    @Suite("サブスクリプション中のとき")
    struct Subscribed {
        let content: PaywallContent?

        init() {
            content = PaywallContent(
                standing: .subscribed(
                    plan: .monthly, periodEndsAt: Date(timeIntervalSince1970: 1_795_118_400),
                    endsAt: Date(timeIntervalSince1970: 1_795_118_400)),
                today: CalendarDay(year: 2026, month: 10, day: 21))
        }

        @Test("支払いが始まる日を書かないこと")
        func noPaymentStart() throws {
            #expect(try #require(content).paymentStart == nil)
        }

        @Test("次の更新日を書かずに、自動で更新することだけを書くこと")
        func renewal() throws {
            #expect(PaywallContent.renewal == "解約しない限り、自動で更新します。")
            #expect(try #require(content).renewalSchedule.isEmpty)
        }
    }

    @Suite("テストユーザーのとき")
    struct TestUser {
        @Test("課金画面を描かないこと")
        func noContent() {
            #expect(
                PaywallContent(
                    standing: .testUser, today: CalendarDay(year: 2026, month: 10, day: 21))
                    == nil)
        }
    }
}
