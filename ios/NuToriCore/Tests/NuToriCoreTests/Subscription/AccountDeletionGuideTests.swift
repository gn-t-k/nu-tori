import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("退会の案内")
struct AccountDeletionGuideTests {
    @Suite("月額のサブスクリプション中で、自動更新がオンのとき")
    struct MonthlyAutoRenewing {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(store: .ok(products: products, autoRenewal: .on), transport: .ok())
        }

        @Test("月額・端末のタイムゾーンでの更新日・月額の価格で、自動更新の案内を出すこと")
        func showsAutoRenewingGuide() async {
            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

            #expect(
                guide
                    == AccountDeletionGuide(
                        plan: .monthly, renewsOn: periodEndDay, usableThrough: periodEndDay,
                        displayPrice: "¥980", renewal: .autoRenewing))
        }
    }

    @Suite("年額のサブスクリプション中で、請求の猶予があるとき")
    struct YearlyInBillingGrace {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(store: .ok(products: products, autoRenewal: .on), transport: .ok())
        }

        @Test("年額の価格と、猶予の終わりを使える日にした案内を出すこと")
        func showsYearlyGuideEndingAtGrace() async {
            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.yearly, billingGrace: .granted(endsAt: graceEndsAt)),
                now: now, timeZone: tokyo, purchases: purchases)

            #expect(
                guide
                    == AccountDeletionGuide(
                        plan: .yearly, renewsOn: periodEndDay, usableThrough: graceEndDay,
                        displayPrice: "¥8,800", renewal: .autoRenewing))
        }
    }

    @Suite("商品を読めないとき")
    struct ProductsUnavailable {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(
                store: .error(URLError(.notConnectedToInternet), autoRenewal: .on), transport: .ok()
            )
        }

        @Test("価格の無い案内を出すこと")
        func showsGuideWithoutPrice() async {
            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide?.displayPrice == nil)
            #expect(guide?.renewal == .autoRenewing)
        }
    }

    @Suite("案内を出さないとき")
    struct NotShown {
        @Suite("自動更新がオフのとき")
        struct AutoRenewalOff {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(
                    store: .ok(products: products, autoRenewal: .off), transport: .ok())
            }

            @Test("出さないこと")
            func notShown() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

                #expect(guide == nil)
            }
        }

        @Suite("今使えるサブスクリプションの更新の情報を読めないとき")
        struct AutoRenewalUnknown {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(
                    store: .ok(products: products, autoRenewal: .unknown), transport: .ok())
            }

            @Test("出さないこと")
            func notShown() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

                #expect(guide == nil)
            }
        }

        @Suite("自動更新がオンのとき")
        struct AutoRenewalOn {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(
                    store: .ok(products: products, autoRenewal: .on), transport: .ok())
            }

            @Test("テストユーザーには出さないこと")
            func testUser() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: .testUser, now: now, timeZone: tokyo, purchases: purchases)

                #expect(guide == nil)
            }

            @Test("無料体験中には出さないこと")
            func freeTrial() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: .regular(
                        freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 1)),
                        subscription: .none),
                    now: now, timeZone: tokyo, purchases: purchases)

                #expect(guide == nil)
            }

            @Test("サブスクリプションの終わりちょうどには出さないこと")
            func atEnd() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: subscribed(.monthly), now: periodEndsAt, timeZone: tokyo,
                    purchases: purchases)

                #expect(guide == nil)
            }

            @Test("サブスクリプションの状態がまだ届いていなければ出さないこと")
            func statusNotYetPulled() async {
                let guide = await AccountDeletionGuide.prepare(
                    status: nil, now: now, timeZone: tokyo, purchases: purchases)

                #expect(guide == nil)
            }
        }
    }

    @Suite("案内の文")
    struct Wording {
        @Suite("価格を読めたとき")
        struct WithPrice {
            let guide: AccountDeletionGuide

            init() {
                guide = AccountDeletionGuide(
                    plan: .yearly, renewsOn: periodEndDay, usableThrough: graceEndDay,
                    displayPrice: "¥8,800", renewal: .autoRenewing)
            }

            @Test("サブスクリプションを、プランの名前と自動更新で書くこと")
            func subscription() {
                #expect(guide.subscriptionText == "年額・自動更新")
            }

            @Test("次の請求を、アカウントの行と同じ月日の書き方と価格で書くこと")
            func nextBilling() {
                #expect(guide.nextBillingText == "11月7日に ¥8,800")
            }

            @Test("解約の段に、解約しても次の更新日まで使えることを書くこと")
            func cancellationStep() {
                #expect(guide.cancellationStepText == "サブスクリプションを解約する。解約しても、11月7日まで使えます。")
            }

            @Test("解約したあとの使える日を、サブスクリプションの終わりを含む日で書くこと")
            func usableThrough() {
                #expect(guide.usableThroughText == "11月18日まで")
            }
        }

        @Suite("価格を読めないとき")
        struct WithoutPrice {
            let guide: AccountDeletionGuide

            init() {
                guide = AccountDeletionGuide(
                    plan: .yearly, renewsOn: periodEndDay, usableThrough: graceEndDay,
                    displayPrice: nil, renewal: .autoRenewing)
            }

            @Test("次の請求を日だけで書くこと")
            func nextBillingWithoutPrice() {
                #expect(guide.nextBillingText == "11月7日")
            }
        }
    }

    @Suite("解約の画面から戻ったとき")
    struct ReturnedFromManageSubscriptions {
        @Suite("自動更新がオフになっていたとき")
        struct TurnedOff {
            let guide: AccountDeletionGuide
            let purchases: SubscriptionPurchases

            init() {
                guide = autoRenewingGuide
                purchases = .fixture(store: .ok(autoRenewal: .off), transport: .ok())
            }

            @Test("解約したことにすること")
            func cancelled() async {
                let reread = await guide.rereadingRenewal(purchases: purchases)

                #expect(reread.renewal == .cancelled)
            }
        }

        @Suite("自動更新がオンのままのとき")
        struct StillOn {
            let guide: AccountDeletionGuide
            let purchases: SubscriptionPurchases

            init() {
                guide = autoRenewingGuide
                purchases = .fixture(store: .ok(autoRenewal: .on), transport: .ok())
            }

            @Test("自動更新のままにすること")
            func stillAutoRenewing() async {
                let reread = await guide.rereadingRenewal(purchases: purchases)

                #expect(reread == guide)
            }
        }

        @Suite("解約したあとに自動更新をオンに戻していたとき")
        struct Resubscribed {
            let guide: AccountDeletionGuide
            let purchases: SubscriptionPurchases

            init() {
                guide = AccountDeletionGuide(
                    plan: .monthly, renewsOn: periodEndDay, usableThrough: periodEndDay,
                    displayPrice: "¥980", renewal: .cancelled)
                purchases = .fixture(store: .ok(autoRenewal: .on), transport: .ok())
            }

            @Test("自動更新に戻すこと")
            func resubscribed() async {
                let reread = await guide.rereadingRenewal(purchases: purchases)

                #expect(reread.renewal == .autoRenewing)
            }
        }

        @Suite("更新の情報を読めないとき")
        struct Unknown {
            let guide: AccountDeletionGuide
            let purchases: SubscriptionPurchases

            init() {
                guide = autoRenewingGuide
                purchases = .fixture(store: .ok(autoRenewal: .unknown), transport: .ok())
            }

            @Test("案内を変えないこと")
            func unknown() async {
                let reread = await guide.rereadingRenewal(purchases: purchases)

                #expect(reread == guide)
            }
        }
    }
}

/// 解約の画面へ行く前の、月額で自動更新の案内
private let autoRenewingGuide = AccountDeletionGuide(
    plan: .monthly, renewsOn: periodEndDay, usableThrough: periodEndDay,
    displayPrice: "¥980", renewal: .autoRenewing)

private let now = Date(timeIntervalSince1970: 1_793_000_000)
private let periodEndsAt = Date(timeIntervalSince1970: 1_794_000_000)
private let graceEndsAt = Date(timeIntervalSince1970: 1_795_000_000)
/// 東京の 11月7日 6:20（UTC では 11月6日）
private let periodEndDay = CalendarDay(year: 2026, month: 11, day: 7)
private let graceEndDay = CalendarDay(year: 2026, month: 11, day: 18)
private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
private let products = [
    SubscriptionProduct(
        id: "app.nu-tori.subscription.monthly", plan: .monthly, displayPrice: "¥980"),
    SubscriptionProduct(
        id: "app.nu-tori.subscription.yearly", plan: .yearly, displayPrice: "¥8,800"),
]

private func subscribed(
    _ plan: SubscriptionStatus.Plan, billingGrace: SubscriptionStatus.BillingGrace = .none
) -> SubscriptionStatus {
    .regular(
        freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 1)),
        subscription: .subscribed(
            plan: plan, periodEndsAt: periodEndsAt, billingGrace: billingGrace))
}
