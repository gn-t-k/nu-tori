import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("サーバーが期限の無い取引を断ったとき")
    struct SubscriptionTransactionWithoutExpiresDate {
        @Test("期限が無いことを理由に断られたと返すこと")
        func returnsExpiresDateMissing() async throws {
            let client = NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: ClientTransportMock.ok(
                    status: .unprocessableContent, json: #"{"code":"expires_date_missing"}"#),
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )

            let result = try await client.reportSubscriptionTransaction(
                requestId: UUID(), signedTransaction: "signed", trigger: .purchase)

            #expect(result == .rejected(.expiresDateMissing))
        }
    }
}
