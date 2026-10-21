import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("サーバーが取引を受け付けなかったとき")
    struct SubscriptionTransactionRejected {
        @Test(
            "断った理由の code を、端末の理由にして返すこと",
            arguments: [
                ("transaction_unverified", NuToriAPIClient.SubscriptionTransactionRejection.unverified),
                ("environment_unsupported", .environmentUnsupported),
                ("product_unknown", .unknownProduct),
                ("expires_date_missing", .expiresDateMissing),
            ])
        func returnsRejection(
            code: String, expected: NuToriAPIClient.SubscriptionTransactionRejection
        ) async throws {
            let client = NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: ClientTransportMock.ok(
                    status: .unprocessableContent, json: #"{"code":"\#(code)"}"#),
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )

            let result = try await client.reportSubscriptionTransaction(
                requestId: UUID(), signedTransaction: "signed", trigger: .purchase)

            #expect(result == .rejected(expected))
        }
    }
}
