public import Foundation
public import OpenAPIRuntime
import OpenAPIURLSession

public struct NuToriAPIClient: Sendable {
    /// - Parameters:
    ///   - appBuild: アプリのビルド番号（`CFBundleVersion`）。すべての要求に `X-App-Build` で付ける
    ///   - sessionToken: 今のセッションのトークン。サインインしていなければ nil を返す
    ///   - appBuildVerdict: 応答を受け取るたびに、サーバーがこのビルドを受け付けたかを知らせる先
    public init(
        environment: APIEnvironment,
        appBuild: Int,
        sessionToken: @escaping @Sendable () async -> String?,
        appBuildVerdict: @escaping @Sendable (AppBuildVerdict) async -> Void
    ) {
        self.init(
            serverURL: environment.serverURL,
            transport: URLSessionTransport(),
            appBuild: appBuild,
            sessionToken: sessionToken,
            appBuildVerdict: appBuildVerdict
        )
    }

    /// UI テストなどで、トランスポートを差し替えるための初期化
    public init(
        serverURL: URL,
        transport: any ClientTransport,
        appBuild: Int,
        sessionToken: @escaping @Sendable () async -> String?,
        appBuildVerdict: @escaping @Sendable (AppBuildVerdict) async -> Void
    ) {
        self.serverURL = serverURL
        self.appBuild = appBuild
        self.sessionToken = sessionToken
        client = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [
                SessionTokenMiddleware(sessionToken: sessionToken),
                AppBuildMiddleware(appBuild: appBuild, verdict: appBuildVerdict),
            ]
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

    let client: Client
    /// 生成したクライアントを通さずに組む要求（バックグラウンドの URLSession で送る写真）のため
    let serverURL: URL
    let appBuild: Int
    let sessionToken: @Sendable () async -> String?
}
