import Foundation
import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("課金画面")
    struct Paywall {
        @Suite("無料体験中に、アカウントの画面の行から開いたとき")
        struct OpenedFromAccountRow {
            let event: ClientUsageEvent

            init() {
                event = .paywallOpened(
                    entry: .accountRow,
                    standing: .freeTrial(
                        lastDay: CalendarDay(year: 2026, month: 10, day: 30), remainingDays: 10))
            }

            @Test("開いたところと、無料体験中であることを載せること")
            func opened() {
                #expect(event.name == "paywall_opened")
                #expect(
                    event.fields == [
                        "entry": .token("account_row"), "standing": .token("free_trial"),
                    ])
                #expect(event.screenToken == nil)
            }
        }

        @Suite("サブスクリプション切れで、知らせのカードから開いたとき")
        struct OpenedFromNoticeCard {
            let event: ClientUsageEvent

            init() {
                event = .paywallOpened(entry: .noticeCard, standing: .expired)
            }

            @Test("開いたところと、サブスクリプション切れであることを載せること")
            func opened() {
                #expect(event.name == "paywall_opened")
                #expect(
                    event.fields == ["entry": .token("notice_card"), "standing": .token("expired")])
                #expect(event.screenToken == nil)
            }
        }

        @Suite("サブスクリプション切れで、入力欄のチップから開いたとき")
        struct OpenedFromComposerChip {
            let event: ClientUsageEvent

            init() {
                event = .paywallOpened(entry: .composerChip, standing: .expired)
            }

            @Test("開いたところと、サブスクリプション切れであることを載せること")
            func opened() {
                #expect(event.name == "paywall_opened")
                #expect(
                    event.fields == [
                        "entry": .token("composer_chip"), "standing": .token("expired"),
                    ])
                #expect(event.screenToken == nil)
            }
        }

        @Suite("サブスクリプション中に、サブスクリプションを待っている推定の行から開いたとき")
        struct OpenedFromAwaitingMeal {
            let event: ClientUsageEvent

            init() {
                event = .paywallOpened(
                    entry: .awaitingMeal,
                    standing: .subscribed(
                        plan: .monthly, periodEndsAt: Date(timeIntervalSince1970: 0),
                        endsAt: Date(timeIntervalSince1970: 0)))
            }

            @Test("開いたところと、サブスクリプション中であることを載せること")
            func opened() {
                #expect(event.name == "paywall_opened")
                #expect(
                    event.fields == [
                        "entry": .token("awaiting_meal"), "standing": .token("subscribed"),
                    ])
                #expect(event.screenToken == nil)
            }
        }

        @Suite("買って閉じたとき")
        struct ClosedPurchased {
            let event: ClientUsageEvent

            init() {
                event = .paywallClosed(.purchased)
            }

            @Test("StoreKit の結果を purchased にすること")
            func closed() {
                #expect(event.name == "paywall_closed")
                #expect(event.fields == ["result": .token("purchased")])
            }
        }

        @Suite("買わずに閉じたとき")
        struct ClosedCancelled {
            let event: ClientUsageEvent

            init() {
                event = .paywallClosed(.cancelled)
            }

            @Test("StoreKit の結果を cancelled にすること")
            func closed() {
                #expect(event.name == "paywall_closed")
                #expect(event.fields == ["result": .token("cancelled")])
            }
        }

        @Suite("承認を待って閉じたとき")
        struct ClosedPending {
            let event: ClientUsageEvent

            init() {
                event = .paywallClosed(.pending)
            }

            @Test("StoreKit の結果を pending にすること")
            func closed() {
                #expect(event.name == "paywall_closed")
                #expect(event.fields == ["result": .token("pending")])
            }
        }
    }
}
