import Foundation
import NuToriCore
import Testing

@Suite("アカウントを削除する確かめの文")
struct AccountDeletionConfirmationTests {
    static let base = "記録はすぐに消え、元に戻せません。ヘルスケアに書き込んだ体重と栄養は残ります。"

    @Suite("無料体験中のとき")
    struct FreeTrial {
        let standing: SubscriptionStanding?

        init() {
            standing = .freeTrial(
                lastDay: CalendarDay(year: 2026, month: 10, day: 30), remainingDays: 10)
        }

        @Test("無料体験の残りが戻らないことを足すこと")
        func addsNote() {
            #expect(
                AccountDeletionConfirmation.message(standing: standing)
                    == "記録はすぐに消え、元に戻せません。ヘルスケアに書き込んだ体重と栄養は残ります。無料体験の残りは、同じ Apple ID で作り直しても戻りません。"
            )
        }
    }

    @Suite("サブスクリプション中のとき")
    struct Subscribed {
        let standing: SubscriptionStanding?

        init() {
            let endsAt = Date(timeIntervalSince1970: 1_795_118_400)
            standing = .subscribed(plan: .monthly, periodEndsAt: endsAt, endsAt: endsAt)
        }

        @Test("足さないこと")
        func doesNotAddNote() {
            #expect(
                AccountDeletionConfirmation.message(standing: standing)
                    == AccountDeletionConfirmationTests.base)
        }
    }

    @Suite("サブスクリプション切れのとき")
    struct Expired {
        let standing: SubscriptionStanding?

        init() {
            standing = .expired
        }

        @Test("足さないこと")
        func doesNotAddNote() {
            #expect(
                AccountDeletionConfirmation.message(standing: standing)
                    == AccountDeletionConfirmationTests.base)
        }
    }

    @Suite("テストユーザーのとき")
    struct TestUser {
        let standing: SubscriptionStanding?

        init() {
            standing = .testUser
        }

        @Test("足さないこと")
        func doesNotAddNote() {
            #expect(
                AccountDeletionConfirmation.message(standing: standing)
                    == AccountDeletionConfirmationTests.base)
        }
    }

    @Suite("状態がまだ届いていないとき")
    struct NotArrived {
        let standing: SubscriptionStanding?

        init() {
            standing = nil
        }

        @Test("足さないこと")
        func doesNotAddNote() {
            #expect(
                AccountDeletionConfirmation.message(standing: standing)
                    == AccountDeletionConfirmationTests.base)
        }
    }
}
