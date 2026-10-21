public import Foundation

extension NuToriAPIClient {
    /// 買うときに App Store に渡す購入者のトークンを求める。まだ無ければサーバーが出し、2度目からは同じ値が返る
    public func issueAppAccountToken() async throws -> AppAccountTokenResult {
        switch try await client.issueAppAccountToken() {
        case .ok(let ok):
            let body = try ok.body.json
            guard let token = UUID(uuidString: body.appAccountToken) else {
                throw MalformedAppAccountTokenError()
            }
            return .issued(token)
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// StoreKit から受け取った取引を知らせる。同じ `requestId` の再送は、サーバーが書かずに今の値を返す
    public func reportSubscriptionTransaction(
        requestId: UUID, signedTransaction: String, trigger: SubscriptionTransactionTrigger
    ) async throws -> SubscriptionTransactionReportResult {
        let output = try await client.reportSubscriptionTransaction(
            body: .json(
                .init(
                    requestId: requestId.canonicalString,
                    signedTransaction: signedTransaction,
                    trigger: .init(trigger))))
        switch output {
        case .ok(let ok):
            switch try ok.body.json {
            case .linked(let linked):
                return .linked(
                    linked.changes.map {
                        RecordKindWireCodings.change(
                            wireKind: $0.kind, recordId: $0.recordId, record: $0.record)
                    })
            case .ownedByOtherAccount:
                return .ownedByOtherAccount
            }
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .unprocessableContent(let response):
            return .rejected(.init(try response.body.json.code))
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum AppAccountTokenResult: Sendable, Equatable {
        case issued(UUID)
        case sessionExpired
        case rateLimited
    }

    public enum SubscriptionTransactionReportResult: Sendable, Equatable {
        /// このアカウントに結びついた。並びは、サブスクリプションの状態、再開した食事・料理の推定の状態
        case linked([SyncChange])
        /// サブスクリプションがほかのアカウントのもの。サーバーは何も書いていない
        case ownedByOtherAccount
        case badRequest
        case sessionExpired
        /// サーバーが受け付けない取引。送り直しても同じ答えになる
        case rejected(SubscriptionTransactionRejection)
        case rateLimited
    }

    struct MalformedAppAccountTokenError: Error {}

    /// 取引を知らせるきっかけ
    public enum SubscriptionTransactionTrigger: Sendable, Equatable {
        /// 買った直後
        case purchase
        /// 「購入を復元」
        case restore
        /// `Transaction.updates` と、終えていない取引
        case transactionUpdates
    }

    /// サーバーが取引を受け付けなかった理由
    public enum SubscriptionTransactionRejection: Sendable, Equatable {
        /// 署名を確かめられない、ほかのアプリの取引
        case unverified
        /// 環境が Production・Sandbox でない（Xcode の StoreKit のテストなど）
        case environmentUnsupported
        /// サーバーが知らない商品
        case unknownProduct
        /// 期限の無い取引（サブスクリプションでない取引）
        case expiresDateMissing

        init(_ code: Components.Schemas.SubscriptionTransactionRejection.CodePayload) {
            switch code {
            case .transactionUnverified: self = .unverified
            case .environmentUnsupported: self = .environmentUnsupported
            case .productUnknown: self = .unknownProduct
            case .expiresDateMissing: self = .expiresDateMissing
            }
        }
    }
}

extension Operations.ReportSubscriptionTransaction.Input.Body.JsonPayload.TriggerPayload {
    fileprivate init(_ trigger: NuToriAPIClient.SubscriptionTransactionTrigger) {
        switch trigger {
        case .purchase: self = .purchase
        case .restore: self = .restore
        case .transactionUpdates: self = .transactionUpdates
        }
    }
}
