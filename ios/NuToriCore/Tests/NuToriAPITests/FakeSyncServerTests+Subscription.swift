import Foundation
import Testing

@testable import NuToriAPI

extension FakeSyncServerTests {
    @Suite("無料体験が終わり、買うと結びつく場面のとき")
    struct LinkingSubscription {
        let expired: SyncedSubscriptionStatus
        let subscribed: SyncedSubscriptionStatus
        let client: NuToriAPIClient

        init() throws {
            expired = .regular(freeTrial: .available(lastDay: "2026-01-30"), subscription: .none)
            subscribed = .regular(
                freeTrial: .available(lastDay: "2026-01-30"),
                subscription: .subscribed(
                    plan: .monthly, periodEndsAt: Date(timeIntervalSince1970: 1_790_000_000),
                    billingGrace: .none))
            client = FakeSyncServerTests.client(
                .init(
                    records: [.subscriptionStatus(expired)],
                    startedOn: FakeSyncServerTests.startedOn,
                    subscription: .init(statusAfterLinking: subscribed)))
        }

        @Test("購入者のトークンを求めると、出したトークンを返すこと")
        func issuesAppAccountToken() async throws {
            let result = try await client.issueAppAccountToken()

            #expect(result == .issued(FakeSyncServer.appAccountToken))
        }

        @Test("取引を知らせると、結びついたと返し、サブスクリプション中の状態を応答と次の取得の両方で返すこと")
        func linksTransaction() async throws {
            let reported = try await client.reportSubscriptionTransaction(
                requestId: UUID(), signedTransaction: "signed", trigger: .purchase)
            let pulled = try await client.pullSyncChanges(afterSequence: 1, clientState: .fixture())

            #expect(reported == .linked([.subscriptionStatus(subscribed)]))
            #expect(FakeSyncServerTests.changes(pulled) == [.subscriptionStatus(subscribed)])
        }
    }

}
