import Foundation
import HTTPTypes
import OpenAPIRuntime

final class ClientTransportMock: ClientTransport, @unchecked Sendable {
    private(set) var requests: [(request: HTTPRequest, body: String?)] = []

    static func ok(status: HTTPResponse.Status = .ok, json: String? = nil) -> ClientTransportMock {
        ClientTransportMock {
            var response = HTTPResponse(status: status)
            guard let json else { return (response, nil) }
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(json))
        }
    }

    static func error(_ error: any Error) -> ClientTransportMock {
        ClientTransportMock { throw error }
    }

    @concurrent func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let bodyText: String? =
            if let body { try await String(collecting: body, upTo: .max) } else { nil }
        requests.append((request, bodyText))
        return try respond()
    }

    private let respond: @Sendable () throws -> (HTTPResponse, HTTPBody?)

    private init(respond: @escaping @Sendable () throws -> (HTTPResponse, HTTPBody?)) {
        self.respond = respond
    }
}
