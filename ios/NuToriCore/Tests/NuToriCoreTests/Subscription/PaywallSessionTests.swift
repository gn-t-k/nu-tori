import Foundation
import HTTPTypes
import NuToriCore
import NuToriTestSupport
import Testing

@MainActor
@Suite("課金画面で買う・復元する")
struct PaywallSessionTests {
    @MainActor
    @Suite("開いて、購入者のトークンを受け取れたとき")
    struct OpenedWithToken {
        let analytics: AnalyticsSessionMock
        let session: PaywallSession

        init() async {
            analytics = .ok()
            session = .fixture(
                standing: .expired, store: .ok(), transport: .subscription { _ in (.ok, nil) },
                analytics: analytics)
            await session.open()
        }

        @Test("開いたところと状態を PostHog に送ること")
        func capturesOpened() {
            #expect(
                analytics.captured == [.paywallOpened(entry: .composerChip, standing: .expired)])
        }

        @Test("トークンを購入の選択肢に渡せること")
        func tokenIssued() {
            #expect(
                session.purchaseToken
                    == .issued(UUID(uuidString: "6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B")!))
            #expect(session.message == nil)
        }
    }

    @MainActor
    @Suite("電波が無いところで開いたとき")
    struct OpenedUnreachable {
        let session: PaywallSession

        init() async {
            session = .fixture(
                standing: .expired, store: .ok(),
                transport: .error(URLError(.notConnectedToInternet)))
            await session.open()
        }

        @Test("買えないこと")
        func tokenUnavailable() {
            #expect(session.purchaseToken == .unavailable)
        }

        @Test("つながらない旨の1行を出すこと")
        func message() {
            #expect(
                session.message == "インターネットにつながらないため、今は始められません。つながるところで、もう一度開いてください。")
        }
    }

    @MainActor
    @Suite("買って、このアカウントに結びついたとき")
    struct PurchasedAndLinked {
        let analytics: AnalyticsSessionMock
        let session: PaywallSession

        init() async {
            analytics = .ok()
            session = .fixture(
                standing: .expired, store: .ok(),
                transport: .subscription { _ in (.ok, paywallLinkedJSON) }, analytics: analytics)
            await session.open()
            await session.purchaseCompleted(.purchased(.sample(id: 1)))
        }

        @Test("シートを閉じること")
        func finishes() {
            #expect(session.isFinished)
        }

        @Test("閉じたとき、買ったことを PostHog に送ること")
        func capturesPurchased() async {
            await session.close()

            #expect(analytics.captured.last == .paywallClosed(.purchased))
        }
    }

    @MainActor
    @Suite("買って、ほかのアカウントのサブスクリプションだったとき")
    struct PurchasedOwnedByOtherAccount {
        let session: PaywallSession

        init() async {
            session = .fixture(
                standing: .expired, store: .ok(),
                transport: .subscription { _ in (.ok, #"{"result":"owned_by_other_account"}"#) })
            await session.open()
            await session.purchaseCompleted(.purchased(.sample(id: 1)))
        }

        @Test("シートを閉じずに、ほかのアカウントで使っていることを出すこと")
        func message() {
            #expect(!session.isFinished)
            #expect(session.message == "このサブスクリプションは、ほかの nu-tori のアカウントで使っています")
        }
    }

    @MainActor
    @Suite("買って、電波が無くて知らせられなかったとき")
    struct PurchasedNotLinkedYet {
        let session: PaywallSession

        init() async {
            session = .fixture(
                standing: .expired, store: .ok(),
                transport: .subscription { _ in throw URLError(.notConnectedToInternet) })
            await session.open()
            await session.purchaseCompleted(.purchased(.sample(id: 1)))
        }

        @Test("支払いが済み、あとで使えるようになることを出すこと")
        func message() {
            #expect(!session.isFinished)
            #expect(session.message == "支払いは済みました。インターネットにつながるところでアプリを開き直すと、使えるようになります。")
        }
    }

    @MainActor
    @Suite("買う画面を閉じたとき")
    struct PurchaseCancelled {
        let analytics: AnalyticsSessionMock
        let session: PaywallSession

        init() async {
            analytics = .ok()
            session = .fixture(
                standing: .expired, store: .ok(), transport: .subscription { _ in (.ok, nil) },
                analytics: analytics)
            await session.open()
            await session.purchaseCompleted(.cancelled)
        }

        @Test("何も出さないこと")
        func noMessage() {
            #expect(!session.isFinished)
            #expect(session.message == nil)
        }

        @Test("閉じたとき、取り消したことを PostHog に送ること")
        func capturesCancelled() async {
            await session.close()

            #expect(analytics.captured.last == .paywallClosed(.cancelled))
        }
    }

    @MainActor
    @Suite("承認を待っているとき")
    struct PurchasePending {
        let analytics: AnalyticsSessionMock
        let session: PaywallSession

        init() async {
            analytics = .ok()
            session = .fixture(
                standing: .expired, store: .ok(), transport: .subscription { _ in (.ok, nil) },
                analytics: analytics)
            await session.open()
            await session.purchaseCompleted(.pending)
        }

        @Test("承認を待っていることを出すこと")
        func message() {
            #expect(session.message == "承認を待っています。承認されると、使えるようになります。")
        }

        @Test("閉じたとき、保留を PostHog に送ること")
        func capturesPending() async {
            await session.close()

            #expect(analytics.captured.last == .paywallClosed(.pending))
        }
    }

    @MainActor
    @Suite("買わずに閉じたとき")
    struct ClosedWithoutPurchase {
        @Test("取り消したことを PostHog に送ること")
        func capturesCancelled() async {
            let analytics = AnalyticsSessionMock.ok()
            let session = PaywallSession.fixture(
                standing: .expired, store: .ok(), transport: .subscription { _ in (.ok, nil) },
                analytics: analytics)
            await session.open()

            await session.close()

            #expect(analytics.captured.last == .paywallClosed(.cancelled))
        }
    }

    @MainActor
    @Suite("購入を復元して、このアカウントに結びついたとき")
    struct RestoredAndLinked {
        @Test("シートを閉じること")
        func finishes() async {
            let session = PaywallSession.fixture(
                standing: .expired, store: .ok(entitlements: [.sample(id: 1)]),
                transport: .subscription { _ in (.ok, paywallLinkedJSON) })
            await session.open()

            await session.restore()

            #expect(session.isFinished)
        }
    }

    @MainActor
    @Suite("購入を復元して、今使える取引が無かったとき")
    struct NothingToRestore {
        @Test("復元できるものが無いことを出すこと")
        func message() async {
            let session = PaywallSession.fixture(
                standing: .expired, store: .ok(), transport: .subscription { _ in (.ok, nil) })
            await session.open()

            await session.restore()

            #expect(!session.isFinished)
            #expect(session.message == "復元できるサブスクリプションがありません")
        }
    }
}

private let paywallLinkedJSON = """
    {"result":"linked","changes":[]}
    """

extension PaywallSession {
    fileprivate static func fixture(
        standing: SubscriptionStanding,
        store: SubscriptionStoreMock,
        transport: ClientTransportMock,
        analytics: AnalyticsSessionMock = .ok()
    ) -> PaywallSession {
        PaywallSession(
            entry: .composerChip, standing: standing,
            purchases: .fixture(store: store, transport: transport),
            capture: { await analytics.capture($0) })
    }
}
