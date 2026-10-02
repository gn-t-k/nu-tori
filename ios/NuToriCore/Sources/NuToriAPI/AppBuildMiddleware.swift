import Foundation
import HTTPTypes
import OpenAPIRuntime

/// すべての要求にビルド番号を付け、426 を生成したコードの解釈より前に締め出しのエラーにする。
/// 経路ごとのスキーマと OpenAPI の各操作には載せない
struct AppBuildMiddleware: ClientMiddleware {
    static let headerName = "X-App-Build"
    static let upgradeRequired = 426

    let appBuild: Int
    let verdict: @Sendable (AppBuildVerdict) async -> Void

    @concurrent func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next:
            @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (
                HTTPResponse, HTTPBody?
            )
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name(Self.headerName)!] = String(appBuild)
        let (response, responseBody) = try await next(request, body, baseURL)
        if response.status.code == Self.upgradeRequired {
            await verdict(.unsupported)
            throw AppBuildUnsupportedError()
        }
        await verdict(.supported)
        return (response, responseBody)
    }
}
