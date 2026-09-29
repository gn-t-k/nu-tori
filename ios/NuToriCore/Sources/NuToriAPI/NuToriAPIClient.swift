public import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

public struct NuToriAPIClient: Sendable {
    /// - Parameter sessionToken: 今のセッションのトークン。サインインしていなければ nil を返す
    public init(
        environment: APIEnvironment,
        sessionToken: @escaping @Sendable () async -> String?
    ) {
        self.init(
            serverURL: environment.serverURL,
            transport: URLSessionTransport(),
            sessionToken: sessionToken
        )
    }

    init(
        serverURL: URL,
        transport: any ClientTransport,
        sessionToken: @escaping @Sendable () async -> String?
    ) {
        client = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [SessionTokenMiddleware(sessionToken: sessionToken)]
        )
    }

    /// Sign in with Apple で得た値でサインインし、セッションを始める
    /// - Parameter timeZone: 端末のタイムゾーン。最初のサインインで、使い始めた日をこの土地の日付にする
    public func startSession(
        idToken: String,
        nonce: String,
        authorizationCode: String,
        timeZone: TimeZone
    ) async throws -> StartSessionResult {
        let output = try await client.createSession(
            body: .json(
                .init(
                    idToken: idToken,
                    nonce: nonce,
                    authorizationCode: authorizationCode,
                    timeZone: timeZone.identifier
                )
            )
        )
        switch output {
        case .created(let created):
            let body = try created.body.json
            return .started(sessionToken: body.sessionToken, accountId: body.accountId)
        case .unauthorized:
            return .rejected
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// アカウントと記録をすべて消す
    public func deleteAccount() async throws -> DeleteAccountResult {
        switch try await client.deleteAccount() {
        case .noContent:
            return .deleted
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum StartSessionResult: Sendable, Equatable {
        case started(sessionToken: String, accountId: String)
        /// ID トークンか認可コードを受け付けなかった
        case rejected
    }

    public enum DeleteAccountResult: Sendable, Equatable {
        case deleted
        case sessionExpired
        case rateLimited
    }

    public struct UndocumentedStatusError: Error, Equatable {
        public let statusCode: Int
    }

    private let client: Client
}
