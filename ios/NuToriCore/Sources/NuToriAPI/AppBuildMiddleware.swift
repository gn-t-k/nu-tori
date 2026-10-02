import Foundation
import HTTPTypes
import OpenAPIRuntime

/// すべての要求にビルド番号を付け、426 を生成したコードの解釈より前に締め出しのエラーにする。
/// 経路ごとのスキーマと OpenAPI の各操作には載せない
struct AppBuildMiddleware: ClientMiddleware {
    static let headerName = "X-App-Build"

    let gate: AppBuildGate

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
        request.headerFields[HTTPField.Name(Self.headerName)!] = String(gate.build)
        let (response, responseBody) = try await next(request, body, baseURL)
        switch await gate.receive(statusCode: response.status.code) {
        case .unsupported:
            throw AppBuildUnsupportedError()
        case .supported:
            return (response, responseBody)
        }
    }
}
