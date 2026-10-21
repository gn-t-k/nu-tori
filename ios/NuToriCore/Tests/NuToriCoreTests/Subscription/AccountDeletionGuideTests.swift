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
            purchases = .fixture(store: .ok(products: products, autoRenewal: .on))
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
            purchases = .fixture(store: .ok(products: products, autoRenewal: .on))
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
                store: .error(URLError(.notConnectedToInternet), autoRenewal: .on))
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
        @Test("自動更新がオフなら出さないこと")
        func autoRenewalOff() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .off))

            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide == nil)
        }

        @Test("今使えるサブスクリプションの更新の情報を読めなければ出さないこと")
        func autoRenewalUnknown() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .unknown))

            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.monthly), now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide == nil)
        }

        @Test("テストユーザーには出さないこと")
        func testUser() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .on))

            let guide = await AccountDeletionGuide.prepare(
                status: .testUser, now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide == nil)
        }

        @Test("無料体験中には出さないこと")
        func freeTrial() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .on))

            let guide = await AccountDeletionGuide.prepare(
                status: .regular(
                    freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 1)),
                    subscription: .none),
                now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide == nil)
        }

        @Test("サブスクリプションの終わりちょうどには出さないこと")
        func atEnd() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .on))

            let guide = await AccountDeletionGuide.prepare(
                status: subscribed(.monthly), now: periodEndsAt, timeZone: tokyo,
                purchases: purchases)

            #expect(guide == nil)
        }

        @Test("サブスクリプションの状態がまだ届いていなければ出さないこと")
        func statusNotYetPulled() async {
            let purchases = SubscriptionPurchases.fixture(
                store: .ok(products: products, autoRenewal: .on))

            let guide = await AccountDeletionGuide.prepare(
                status: nil, now: now, timeZone: tokyo, purchases: purchases)

            #expect(guide == nil)
        }
    }

    @Suite("案内の文")
    struct Wording {
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

        @Test("価格を読めないときは、次の請求を日だけで書くこと")
        func nextBillingWithoutPrice() {
            let withoutPrice = AccountDeletionGuide(
                plan: .yearly, renewsOn: periodEndDay, usableThrough: graceEndDay,
                displayPrice: nil, renewal: .autoRenewing)

            #expect(withoutPrice.nextBillingText == "11月7日")
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

    @Suite("解約の画面から戻ったとき")
    struct ReturnedFromManageSubscriptions {
        let guide: AccountDeletionGuide

        init() {
            guide = AccountDeletionGuide(
                plan: .monthly, renewsOn: periodEndDay, usableThrough: periodEndDay,
                displayPrice: "¥980", renewal: .autoRenewing)
        }

        @Test("自動更新がオフになっていれば、解約したことにすること")
        func cancelled() async {
            let purchases = SubscriptionPurchases.fixture(store: .ok(autoRenewal: .off))

            let reread = await guide.rereadingRenewal(purchases: purchases)

            #expect(reread.renewal == .cancelled)
        }

        @Test("自動更新がオンのままなら、自動更新のままにすること")
        func stillAutoRenewing() async {
            let purchases = SubscriptionPurchases.fixture(store: .ok(autoRenewal: .on))

            let reread = await guide.rereadingRenewal(purchases: purchases)

            #expect(reread == guide)
        }

        @Test("解約したあとに自動更新をオンに戻していれば、自動更新に戻すこと")
        func resubscribed() async {
            let cancelled = AccountDeletionGuide(
                plan: .monthly, renewsOn: periodEndDay, usableThrough: periodEndDay,
                displayPrice: "¥980", renewal: .cancelled)
            let purchases = SubscriptionPurchases.fixture(store: .ok(autoRenewal: .on))

            let reread = await cancelled.rereadingRenewal(purchases: purchases)

            #expect(reread.renewal == .autoRenewing)
        }

        @Test("更新の情報を読めなければ、案内を変えないこと")
        func unknown() async {
            let purchases = SubscriptionPurchases.fixture(store: .ok(autoRenewal: .unknown))

            let reread = await guide.rereadingRenewal(purchases: purchases)

            #expect(reread == guide)
        }
    }
}

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

extension SubscriptionPurchases {
    /// 退会の案内は StoreKit の口だけを読み、サーバーには何も送らない
    fileprivate static func fixture(store: SubscriptionStoreMock) -> SubscriptionPurchases {
        SubscriptionPurchases(
            store: store,
            client: NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: ClientTransportMock.ok(),
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            ),
            applyReportedChanges: { _ in }
        )
    }
}
