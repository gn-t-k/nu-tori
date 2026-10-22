#if DEBUG
    public import Foundation
    import HTTPTypes
    import OpenAPIRuntime

    extension FakeSyncServer {
        /// 購入者のトークンを求める要求に、どの場面でも返すトークン
        public static let appAccountToken = UUID(
            uuidString: "00000000-0000-4000-8000-0000000000a7")!

        /// 取引の知らせへの答え方。署名は確かめず、どの取引もこのアカウントに結びつける
        public struct SubscriptionAnswers: Sendable {
            /// 結びついたあとのサブスクリプションの状態
            public let statusAfterLinking: SyncedSubscriptionStatus

            public init(statusAfterLinking: SyncedSubscriptionStatus) {
                self.statusAfterLinking = statusAfterLinking
            }
        }

        func issueAppAccountToken() throws -> (HTTPResponse, HTTPBody?) {
            try json(
                .ok,
                Components.Schemas.AppAccountToken(
                    appAccountToken: Self.appAccountToken.canonicalString))
        }

        /// 結びついたと返し、状態の記録を応答に載せて、同期でも届くよう置く。答え方が無い場面は 404
        func linkSubscriptionTransaction() throws -> (HTTPResponse, HTTPBody?) {
            guard let answers = scenario.subscription else {
                return (HTTPResponse(status: .notFound), nil)
            }
            let changes: [SyncChange] = [.subscriptionStatus(answers.statusAfterLinking)]
            record(changes)
            return try json(
                .ok,
                Components.Schemas.SubscriptionTransactionReport.linked(
                    .init(
                        result: .linked,
                        changes: try changes.map { try .init($0) })))
        }
    }
#endif
