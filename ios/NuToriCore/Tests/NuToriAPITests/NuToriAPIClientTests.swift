import Foundation
import HTTPTypes
import NuToriTestSupport
import Testing

@testable import NuToriAPI

@Suite("API のクライアント")
struct NuToriAPIClientTests {
    @Suite("セッションを始める")
    struct StartSession {
        @Suite("サーバーが受け付けたとき")
        struct Accepted {
            let credentials: Credentials
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                credentials = Credentials(
                    idToken: "id-token", nonce: "nonce", code: "code",
                    timeZone: TimeZone(identifier: "Asia/Tokyo")!)
                transport = .ok(
                    status: .created, json: #"{"sessionToken":"session-1","accountId":"account-1"}"#
                )
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { nil }
                )
            }

            @Test("セッションのトークンとアカウント ID を返すこと")
            func returnsSessionTokenAndAccountId() async throws {
                let result = try await client.startSession(
                    idToken: credentials.idToken,
                    nonce: credentials.nonce,
                    authorizationCode: credentials.code,
                    timeZone: credentials.timeZone
                )

                #expect(result == .started(sessionToken: "session-1", accountId: "account-1"))
            }

            @Test("ID トークンと nonce と認可コードと端末のタイムゾーンを POST /v1/sessions に送ること")
            func sendsCredentials() async throws {
                _ = try await client.startSession(
                    idToken: credentials.idToken,
                    nonce: credentials.nonce,
                    authorizationCode: credentials.code,
                    timeZone: credentials.timeZone
                )

                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .post)
                #expect(sent.request.path == "/v1/sessions")
                let body = try JSONDecoder().decode(
                    [String: String].self, from: Data((sent.body ?? "").utf8))
                #expect(
                    body == [
                        "idToken": credentials.idToken,
                        "nonce": credentials.nonce,
                        "authorizationCode": credentials.code,
                        "timeZone": credentials.timeZone.identifier,
                    ]
                )
            }
        }

        @Suite("サーバーが受け付けなかったとき")
        struct Rejected {
            let credentials: Credentials
            let client: NuToriAPIClient

            init() {
                credentials = Credentials(
                    idToken: "id-token", nonce: "nonce", code: "code",
                    timeZone: TimeZone(identifier: "Asia/Tokyo")!)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    sessionToken: { nil }
                )
            }

            @Test("受け付けなかったと返すこと")
            func returnsRejected() async throws {
                let result = try await client.startSession(
                    idToken: credentials.idToken,
                    nonce: credentials.nonce,
                    authorizationCode: credentials.code,
                    timeZone: credentials.timeZone
                )

                #expect(result == .rejected)
            }
        }

        struct Credentials {
            let idToken: String
            let nonce: String
            let code: String
            let timeZone: TimeZone
        }
    }

    @Suite("アカウントを消す")
    struct DeleteAccount {
        @Suite("消せたとき")
        struct Deleted {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .ok(status: .noContent)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { "session-1" }
                )
            }

            @Test("消したと返すこと")
            func returnsDeleted() async throws {
                #expect(try await client.deleteAccount() == .deleted)
            }

            @Test("セッションのトークンを Bearer で DELETE /v1/account に送ること")
            func sendsSessionToken() async throws {
                _ = try await client.deleteAccount()

                let sent = try #require(transport.requests.first)
                #expect(sent.request.method == .delete)
                #expect(sent.request.path == "/v1/account")
                #expect(sent.request.headerFields[.authorization] == "Bearer session-1")
            }
        }

        @Suite("セッションが切れているとき")
        struct SessionExpired {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .unauthorized),
                    sessionToken: { "session-1" }
                )
            }

            @Test("セッションが切れていると返すこと")
            func returnsSessionExpired() async throws {
                #expect(try await client.deleteAccount() == .sessionExpired)
            }
        }

        @Suite("回数の歯止めにかかったとき")
        struct RateLimited {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .tooManyRequests),
                    sessionToken: { "session-1" }
                )
            }

            @Test("回数の歯止めにかかったと返すこと")
            func returnsRateLimited() async throws {
                #expect(try await client.deleteAccount() == .rateLimited)
            }
        }

        @Suite("サインインしていないとき")
        struct SignedOut {
            let transport: ClientTransportMock
            let client: NuToriAPIClient

            init() {
                transport = .ok(status: .unauthorized)
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: transport,
                    sessionToken: { nil }
                )
            }

            @Test("Authorization を付けずに送ること")
            func sendsWithoutAuthorization() async throws {
                _ = try await client.deleteAccount()

                let sent = try #require(transport.requests.first)
                #expect(sent.request.headerFields[.authorization] == nil)
            }
        }

        @Suite("文書に無い状態コードが返ったとき")
        struct UndocumentedStatus {
            let client: NuToriAPIClient

            init() {
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(status: .internalServerError),
                    sessionToken: { "session-1" }
                )
            }

            @Test("状態コードを添えて投げること")
            func throwsWithStatusCode() async {
                await #expect(throws: NuToriAPIClient.UndocumentedStatusError(statusCode: 500)) {
                    try await client.deleteAccount()
                }
            }
        }
    }
}
