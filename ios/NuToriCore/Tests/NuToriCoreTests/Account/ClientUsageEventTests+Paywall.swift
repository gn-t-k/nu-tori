import Foundation
import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("課金画面")
    struct Paywall {
        @Test("開いたところと、無料体験中かサブスクリプション切れかを載せること")
        func opened() {
            let events: [ClientUsageEvent] = [
                .paywallOpened(
                    entry: .accountRow,
                    standing: .freeTrial(
                        lastDay: CalendarDay(year: 2026, month: 10, day: 30), remainingDays: 10)),
                .paywallOpened(entry: .noticeCard, standing: .expired),
                .paywallOpened(entry: .composerChip, standing: .expired),
                .paywallOpened(
                    entry: .awaitingMeal,
                    standing: .subscribed(
                        plan: .monthly, periodEndsAt: Date(timeIntervalSince1970: 0),
                        endsAt: Date(timeIntervalSince1970: 0))),
            ]

            #expect(events.map(\.name) == Array(repeating: "paywall_opened", count: 4))
            #expect(
                events.map(\.fields) == [
                    ["entry": .token("account_row"), "standing": .token("free_trial")],
                    ["entry": .token("notice_card"), "standing": .token("expired")],
                    ["entry": .token("composer_chip"), "standing": .token("expired")],
                    ["entry": .token("awaiting_meal"), "standing": .token("subscribed")],
                ])
            #expect(events.allSatisfy { $0.screenToken == nil })
        }

        @Test("閉じたときの StoreKit の結果を載せること")
        func closed() {
            let events: [ClientUsageEvent] = [
                .paywallClosed(.purchased), .paywallClosed(.cancelled), .paywallClosed(.pending),
            ]

            #expect(events.map(\.name) == Array(repeating: "paywall_closed", count: 3))
            #expect(
                events.map(\.fields) == [
                    ["result": .token("purchased")],
                    ["result": .token("cancelled")],
                    ["result": .token("pending")],
                ])
        }
    }
}
