import Foundation
import NuToriCore
import Testing

@Suite("アカウントの画面のサブスクリプションの行")
struct AccountSubscriptionRowTests {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    /// 東京の11月20日 5:00。UTC では11月19日
    static let periodEndsAt = Date(timeIntervalSince1970: 1_795_118_400)
    /// 東京の12月6日 5:00（請求の猶予の終わり）
    static let graceEndsAt = Date(timeIntervalSince1970: 1_796_500_800)

    @Suite("無料体験中のとき")
    struct FreeTrial {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .freeTrial(
                    lastDay: CalendarDay(year: 2026, month: 10, day: 30), remainingDays: 10),
                autoRenewal: .unknown, timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("残りの日数を値にすること")
        func value() {
            #expect(row.value == "無料体験 あと 10 日")
        }

        @Test("押すと課金画面を開くこと")
        func opensPaywall() {
            #expect(row.opensPaywall)
        }
    }

    @Suite("サブスクリプション中で、自動更新がオンのとき")
    struct SubscribedRenewing {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .subscribed(
                    plan: .monthly, periodEndsAt: AccountSubscriptionRowTests.periodEndsAt,
                    endsAt: AccountSubscriptionRowTests.graceEndsAt),
                autoRenewal: .on, timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("月額と、端末のタイムゾーンでの期限の日を更新日にすること")
        func value() {
            #expect(row.value == "月額・11月20日に更新")
        }

        @Test("押すと課金画面を開くこと")
        func opensPaywall() {
            #expect(row.opensPaywall)
        }
    }

    @Suite("年額のサブスクリプション中で、自動更新を読めないとき")
    struct SubscribedYearlyUnknownRenewal {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .subscribed(
                    plan: .yearly, periodEndsAt: AccountSubscriptionRowTests.periodEndsAt,
                    endsAt: AccountSubscriptionRowTests.periodEndsAt),
                autoRenewal: .unknown, timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("年額と更新日を値にすること")
        func value() {
            #expect(row.value == "年額・11月20日に更新")
        }
    }

    @Suite("サブスクリプション中で、自動更新がオフのとき")
    struct SubscribedCancelled {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .subscribed(
                    plan: .monthly, periodEndsAt: AccountSubscriptionRowTests.periodEndsAt,
                    endsAt: AccountSubscriptionRowTests.graceEndsAt),
                autoRenewal: .off, timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("解約したことと、サブスクリプションの終わりの日を値にすること")
        func value() {
            #expect(row.value == "解約しました・12月6日まで使えます")
        }
    }

    @Suite("サブスクリプション切れのとき")
    struct Expired {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .expired, autoRenewal: .unknown,
                timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("切れたことを値にすること")
        func value() {
            #expect(row.value == "サブスクリプション切れ")
        }

        @Test("押すと課金画面を開くこと")
        func opensPaywall() {
            #expect(row.opensPaywall)
        }
    }

    @Suite("テストユーザーのとき")
    struct TestUser {
        let row: AccountSubscriptionRow

        init() {
            row = AccountSubscriptionRow(
                standing: .testUser, autoRenewal: .unknown,
                timeZone: AccountSubscriptionRowTests.tokyo)
        }

        @Test("テストユーザーと値にすること")
        func value() {
            #expect(row.value == "テストユーザー")
        }

        @Test("押しても課金画面を開かないこと")
        func doesNotOpenPaywall() {
            #expect(!row.opensPaywall)
        }
    }
}
