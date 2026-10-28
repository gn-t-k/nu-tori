import Foundation
import HTTPTypes
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

@Suite("サブスクリプションの取引の知らせ")
struct SubscriptionPurchasesTests {
    @Suite("買って、サーバーが結びつけたとき")
    struct PurchaseLinked {
        let store: SubscriptionStoreMock
        let transport: ClientTransportMock
        private let applied: ChangesRecorder
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            transport = .subscription { _ in (.ok, linkedJSON) }
            let applied = ChangesRecorder()
            self.applied = applied
            purchases = .fixture(
                store: store, transport: transport,
                applyReportedChanges: { applied.changes += $0 }, newRequestId: { requestId })
        }

        @Test("署名つきの取引を、買った直後のきっかけと要求の ID で知らせること")
        func reportsWithPurchaseTrigger() async throws {
            _ = await purchases.reportPurchase(.sample(id: 1))

            #expect(
                try reportBodies(transport) == [
                    [
                        "requestId": "6a1f2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d",
                        "signedTransaction": "jws-1", "trigger": "purchase",
                    ]
                ])
        }

        @Test("結びついたと返し、取引を終えること")
        func returnsLinkedAndFinishes() async {
            let outcome = await purchases.reportPurchase(.sample(id: 1))

            #expect(outcome == .linked)
            #expect(store.finished == [1])
        }

        @Test("応答のサブスクリプションの状態をキャッシュに当てること")
        func appliesChanges() async {
            _ = await purchases.reportPurchase(.sample(id: 1))

            #expect(
                applied.changes == [
                    .subscriptionStatus(
                        .regular(
                            freeTrial: .available(lastDay: "2026-11-19"),
                            subscription: .subscribed(
                                plan: .monthly,
                                periodEndsAt: Date(timeIntervalSince1970: 1_796_094_245.678),
                                billingGrace: .none)))
                ])
        }
    }

    @Suite("買って、ほかのアカウントのサブスクリプションだったとき")
    struct PurchaseOwnedByOtherAccount {
        let store: SubscriptionStoreMock
        private let applied: ChangesRecorder
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            let applied = ChangesRecorder()
            self.applied = applied
            purchases = .fixture(
                store: store,
                transport: .subscription { _ in (.ok, #"{"result":"owned_by_other_account"}"#) },
                applyReportedChanges: { applied.changes += $0 })
        }

        @Test("ほかのアカウントのものと返し、取引を終えること")
        func returnsOwnedByOtherAccountAndFinishes() async {
            let outcome = await purchases.reportPurchase(.sample(id: 1))

            #expect(outcome == .ownedByOtherAccount)
            #expect(store.finished == [1])
        }

        @Test("キャッシュに何も当てないこと")
        func appliesNothing() async {
            _ = await purchases.reportPurchase(.sample(id: 1))

            #expect(applied.changes.isEmpty)
        }
    }

    @Suite("買って、電波が無くて知らせられなかったとき")
    struct PurchaseUnreachable {
        let store: SubscriptionStoreMock
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            purchases = .fixture(
                store: store,
                transport: .subscription { _ in throw URLError(.notConnectedToInternet) })
        }

        @Test("まだ結びついていないと返し、取引を終えずに残すこと")
        func keepsTransactionUnfinished() async {
            let outcome = await purchases.reportPurchase(.sample(id: 1))

            #expect(outcome == .notLinkedYet(.unreachable))
            #expect(store.finished.isEmpty)
        }
    }

    @Suite("買って、サーバーが答えられなかったとき")
    struct PurchaseServerFailed {
        let store: SubscriptionStoreMock
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            purchases = .fixture(
                store: store, transport: .subscription { _ in (.internalServerError, nil) })
        }

        @Test("まだ結びついていないと返し、取引を終えずに残すこと")
        func keepsTransactionUnfinished() async {
            let outcome = await purchases.reportPurchase(.sample(id: 1))

            #expect(outcome == .notLinkedYet(.retryLater))
            #expect(store.finished.isEmpty)
        }
    }

    @Suite("買って、サーバーが取引を受け付けなかったとき")
    struct PurchaseRejected {
        let store: SubscriptionStoreMock
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            purchases = .fixture(
                store: store,
                transport: .subscription { _ in
                    (.unprocessableContent, #"{"code":"environment_unsupported"}"#)
                })
        }

        @Test("受け付けなかったと返し、取引を終えること")
        func finishesTransaction() async {
            let outcome = await purchases.reportPurchase(.sample(id: 1))

            #expect(outcome == .rejected)
            #expect(store.finished == [1])
        }
    }

    @Suite("課金画面に渡す購入者のトークンを求めるとき")
    struct AppAccountToken {
        @Suite("サーバーが出したとき")
        struct Issued {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(store: .ok(), transport: .subscription { _ in (.ok, nil) })
            }

            @Test("サーバーが出したトークンを返すこと")
            func returnsToken() async {
                #expect(
                    await purchases.appAccountToken()
                        == .issued(UUID(uuidString: "6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B")!))
            }
        }

        @Suite("電波が無いとき")
        struct Unreachable {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(
                    store: .ok(), transport: .error(URLError(.notConnectedToInternet)))
            }

            @Test("つながらなかったと返すこと")
            func returnsUnreachable() async {
                #expect(await purchases.appAccountToken() == .unavailable(.unreachable))
            }
        }

        @Suite("セッションが切れていたとき")
        struct SessionExpired {
            let purchases: SubscriptionPurchases

            init() {
                purchases = .fixture(store: .ok(), transport: .ok(status: .unauthorized))
            }

            @Test("あとでもう一度と返すこと")
            func returnsRetryLater() async {
                #expect(await purchases.appAccountToken() == .unavailable(.retryLater))
            }
        }
    }

    @Suite("知らせられなかった取引を開き直して知らせるとき")
    struct ResendOnNextOpen {
        let reachability: ReachabilitySwitch
        let store: SubscriptionStoreMock
        let transport: ClientTransportMock
        let purchases: SubscriptionPurchases

        init() {
            let reachability = ReachabilitySwitch(isReachable: false)
            self.reachability = reachability
            store = .ok(unfinished: [.sample(id: 1)])
            transport = .subscription { _ in
                guard reachability.isReachable else { throw URLError(.notConnectedToInternet) }
                return (.ok, linkedJSON)
            }
            purchases = .fixture(store: store, transport: transport)
        }

        @Test("終えていない取引を、Transaction.updates のきっかけで知らせて終えること")
        func reportsUnfinishedAndFinishes() async throws {
            _ = await purchases.reportPurchase(.sample(id: 1))
            reachability.isReachable = true

            await purchases.reportUnfinishedTransactions()

            #expect(
                try reportBodies(transport).map { $0["trigger"] } == [
                    "purchase", "transaction_updates",
                ])
            #expect(store.finished == [1])
        }

        @Test("同じ取引には、同じ要求の ID で送り直すこと")
        func resendsWithSameRequestId() async throws {
            _ = await purchases.reportPurchase(.sample(id: 1))
            reachability.isReachable = true

            await purchases.reportUnfinishedTransactions()

            let requestIds = try reportBodies(transport).map { $0["requestId"] }
            #expect(requestIds.count == 2)
            #expect(requestIds[0] == requestIds[1])
        }
    }

    @Suite("Transaction.updates に取引が流れたとき")
    struct Updates {
        let store: SubscriptionStoreMock
        let transport: ClientTransportMock
        let purchases: SubscriptionPurchases

        init() {
            store = .ok()
            transport = .subscription { _ in (.ok, linkedJSON) }
            purchases = .fixture(store: store, transport: transport)
        }

        @Test("Transaction.updates のきっかけで知らせて、取引を終えること")
        func reportsAndFinishes() async throws {
            let watching = Task { await purchases.watchTransactionUpdates() }
            store.yieldUpdate(.sample(id: 2))
            store.endUpdates()
            await watching.value

            #expect(try reportBodies(transport).map { $0["trigger"] } == ["transaction_updates"])
            #expect(store.finished == [2])
        }
    }

    @Suite("終えていない取引が、Transaction.updates にも流れたとき")
    struct UnfinishedAlsoInUpdates {
        let store: SubscriptionStoreMock
        let transport: ClientTransportMock
        private let gate: ResponseGate
        let purchases: SubscriptionPurchases

        init() {
            let gate = ResponseGate()
            self.gate = gate
            store = .ok(unfinished: [.sample(id: 3)])
            transport = .subscription { _ in
                await gate.wait()
                return (.ok, linkedJSON)
            }
            purchases = .fixture(store: store, transport: transport)
        }

        @Test("応答を待っているあいだに流れても、取引を1度だけ送ること")
        func reportsOnceWhileInFlight() async throws {
            let unfinished = Task { await purchases.reportUnfinishedTransactions() }
            await gate.waitUntilWaiting()
            let watching = Task { await purchases.watchTransactionUpdates() }
            store.yieldUpdate(.sample(id: 3))
            store.endUpdates()
            await gate.open()
            await unfinished.value
            await watching.value

            #expect(try reportBodies(transport).count == 1)
        }

        @Test("知らせて終えたあとに流れても、もう送らないこと")
        func doesNotReportAfterFinished() async throws {
            await gate.open()
            await purchases.reportUnfinishedTransactions()
            let watching = Task { await purchases.watchTransactionUpdates() }
            store.yieldUpdate(.sample(id: 3))
            store.endUpdates()
            await watching.value

            #expect(try reportBodies(transport).count == 1)
            #expect(store.finished == [3])
        }
    }

    @Suite("購入を復元したとき")
    struct Restore {
        let store: SubscriptionStoreMock
        let transport: ClientTransportMock
        let purchases: SubscriptionPurchases

        init() {
            store = .ok(entitlements: [.sample(id: 4)])
            transport = .subscription { _ in (.ok, linkedJSON) }
            purchases = .fixture(store: store, transport: transport)
        }

        @Test("App Store と突き合わせてから、今使える取引を復元のきっかけで知らせること")
        func syncsThenReportsEntitlements() async throws {
            let outcome = await purchases.restore()

            #expect(outcome == .linked)
            #expect(store.syncCount == 1)
            #expect(try reportBodies(transport).map { $0["signedTransaction"] } == ["jws-4"])
            #expect(try reportBodies(transport).map { $0["trigger"] } == ["restore"])
        }
    }

    @Suite("この起動で知らせた取引を、購入を復元で知らせ直すとき")
    struct RestoreAfterPurchase {
        let transport: ClientTransportMock
        let purchases: SubscriptionPurchases

        init() {
            transport = .subscription { _ in (.ok, linkedJSON) }
            purchases = .fixture(store: .ok(entitlements: [.sample(id: 4)]), transport: transport)
        }

        @Test("復元のきっかけで、別の要求の ID で送り直すこと")
        func reportsAgainWithNewRequestId() async throws {
            _ = await purchases.reportPurchase(.sample(id: 4))

            _ = await purchases.restore()

            let bodies = try reportBodies(transport)
            #expect(bodies.map { $0["trigger"] } == ["purchase", "restore"])
            #expect(bodies[0]["requestId"] != bodies[1]["requestId"])
        }
    }

    @Suite("購入を復元して、ほかのアカウントのサブスクリプションだったとき")
    struct RestoreOwnedByOtherAccount {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(
                store: .ok(entitlements: [.sample(id: 4)]),
                transport: .subscription { _ in (.ok, #"{"result":"owned_by_other_account"}"#) })
        }

        @Test("ほかのアカウントのものと返すこと")
        func returnsOwnedByOtherAccount() async {
            let outcome = await purchases.restore()

            #expect(outcome == .ownedByOtherAccount)
        }
    }

    @Suite("購入を復元して、今使える取引が無かったとき")
    struct RestoreNothing {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(
                store: .ok(entitlements: []), transport: .subscription { _ in (.ok, linkedJSON) })
        }

        @Test("復元するものが無いと返すこと")
        func returnsNothingToRestore() async {
            let outcome = await purchases.restore()

            #expect(outcome == .nothingToRestore)
        }
    }

    @Suite("購入を復元して、知らせられなかったとき")
    struct RestoreUnreachable {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(
                store: .ok(entitlements: [.sample(id: 4)]),
                transport: .subscription { _ in throw URLError(.notConnectedToInternet) })
        }

        @Test("つながらなかったと返すこと")
        func returnsUnreachable() async {
            let outcome = await purchases.restore()

            #expect(outcome == .failed(.unreachable))
        }
    }

    @Suite("購入を復元して、App Store と突き合わせられなかったが、今使える取引があるとき")
    struct RestoreSyncFailedWithEntitlements {
        let syncError: NSError
        let transport: ClientTransportMock
        let reporting: ErrorReportingSessionMock
        let purchases: SubscriptionPurchases

        init() {
            syncError = NSError(domain: "StoreKit.StoreKitError", code: 2)
            transport = .subscription { _ in (.ok, linkedJSON) }
            reporting = .ok()
            purchases = .fixture(
                store: .ok(entitlements: [.sample(id: 4)], syncResult: .failed(syncError)),
                transport: transport, errorReporting: reporting)
        }

        @Test("今使える取引を復元のきっかけで知らせ、結びついたと返すこと")
        func reportsEntitlements() async throws {
            let outcome = await purchases.restore()

            #expect(outcome == .linked)
            #expect(try reportBodies(transport).map { $0["trigger"] } == ["restore"])
        }

        @Test("突き合わせられなかった誤りの種類を Sentry に送ること")
        func reportsSyncFailure() async throws {
            _ = await purchases.restore()

            #expect(reporting.reported == [.appStoreSync])
            let cause = try #require(reporting.reports.first?.cause)
            #expect(cause == FailureCause(syncError))
        }
    }

    @Suite("購入を復元して、App Store と突き合わせられず、今使える取引も無いとき")
    struct RestoreSyncFailedWithoutEntitlements {
        let purchases: SubscriptionPurchases

        init() {
            purchases = .fixture(
                store: .ok(
                    entitlements: [],
                    syncResult: .failed(NSError(domain: "StoreKit.StoreKitError", code: 2))),
                transport: .subscription { _ in (.ok, linkedJSON) })
        }

        @Test("復元するものが無いとは言わず、失敗したと返すこと")
        func returnsFailed() async {
            let outcome = await purchases.restore()

            #expect(outcome == .failed(.retryLater))
        }
    }

    @Suite("購入を復元して、つながらず App Store と突き合わせられなかったとき")
    struct RestoreSyncUnreachable {
        let reporting: ErrorReportingSessionMock
        let purchases: SubscriptionPurchases

        init() {
            reporting = .ok()
            purchases = .fixture(
                store: .ok(
                    entitlements: [], syncResult: .failed(URLError(.notConnectedToInternet))),
                transport: .subscription { _ in (.ok, linkedJSON) }, errorReporting: reporting)
        }

        @Test("つながらなかったと返し、Sentry に送らないこと")
        func returnsUnreachable() async {
            let outcome = await purchases.restore()

            #expect(outcome == .failed(.unreachable))
            #expect(reporting.reported.isEmpty)
        }
    }

    @Suite("Apple アカウントへのサインインを閉じたとき")
    struct RestoreCancelled {
        let transport: ClientTransportMock
        let purchases: SubscriptionPurchases

        init() {
            transport = .subscription { _ in (.ok, linkedJSON) }
            purchases = .fixture(
                store: .ok(entitlements: [.sample(id: 4)], syncResult: .cancelled),
                transport: transport)
        }

        @Test("閉じたと返し、何も知らせないこと")
        func reportsNothing() async throws {
            let outcome = await purchases.restore()

            #expect(outcome == .cancelled)
            #expect(try reportBodies(transport).isEmpty)
        }
    }

    @Suite("商品を読むとき")
    struct Products {
        let monthly: SubscriptionProduct
        let yearly: SubscriptionProduct
        let purchases: SubscriptionPurchases

        init() {
            monthly = SubscriptionProduct(id: monthlyId, plan: .monthly, displayPrice: "¥980")
            yearly = SubscriptionProduct(
                id: "app.nu_tori.subscription.yearly", plan: .yearly, displayPrice: "¥8,800")
            let other = SubscriptionProduct(id: "other", plan: .monthly, displayPrice: "¥1")
            purchases = .fixture(
                store: .ok(products: [yearly, other, monthly]), transport: .ok())
        }

        @Test("月額と年額の商品を返すこと")
        func returnsKnownProducts() async throws {
            #expect(try await purchases.products() == [monthly, yearly])
        }
    }
}

private let monthlyId = "app.nu_tori.subscription.monthly"
private let requestId = UUID(uuidString: "6A1F2C3D-4E5F-4A6B-8C7D-9E0F1A2B3C4D")!
private let linkedJSON = """
    {"result":"linked","changes":[
      {"kind":"subscription_status","recordId":"00000000-0000-4000-8000-0000000000f1",
       "record":{"type":"regular","freeTrial":{"type":"available","lastDay":"2026-11-19"},
                 "subscription":{"type":"subscribed","plan":"monthly",
                                 "periodEndsAt":"2026-12-01T03:04:05.678Z","billingGrace":{"type":"none"}}}}
    ]}
    """

/// 取引を知らせた要求の本文
private func reportBodies(_ transport: ClientTransportMock) throws -> [[String: String]] {
    try transport.requests.filter { $0.request.path == "/v1/subscription-transactions" }.map {
        try JSONDecoder().decode([String: String].self, from: Data(try #require($0.body).utf8))
    }
}

/// 取引を知らせる要求の応答を、テストが開けるまで待たせる
private actor ResponseGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var arrivals: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        for arrival in arrivals { arrival.resume() }
        arrivals = []
        await withCheckedContinuation { waiters.append($0) }
    }

    /// 要求が1つ、応答を待ち始めるまで待つ
    func waitUntilWaiting() async {
        guard waiters.isEmpty else { return }
        await withCheckedContinuation { arrivals.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters = []
    }
}

/// 応答の記録を当てた先
private final class ChangesRecorder: @unchecked Sendable {
    var changes: [SyncChange] = []
}
