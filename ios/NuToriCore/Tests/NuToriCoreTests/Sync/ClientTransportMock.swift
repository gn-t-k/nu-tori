import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

final class ClientTransportMock: ClientTransport, @unchecked Sendable {
    private(set) var requests: [(request: HTTPRequest, body: String?)] = []

    var pushBodies: [NSDictionary] {
        get throws {
            try requests.filter { $0.request.path == "/v1/sync/writes" }.map {
                try #require(
                    JSONSerialization.jsonObject(with: Data(($0.body ?? "").utf8)) as? NSDictionary)
            }
        }
    }

    var pullQueries: [[String: String]] {
        get throws {
            try requests.filter { $0.request.path?.hasPrefix("/v1/sync/changes") == true }.map {
                let components = try #require(
                    URLComponents(string: "https://api.example\($0.request.path ?? "")"))
                return Dictionary(
                    uniqueKeysWithValues: (components.queryItems ?? []).map {
                        ($0.name, $0.value ?? "")
                    })
            }
        }
    }

    static let emptyPage = #"{"changes":[],"hasMore":false,"nextAfterSequence":0,"startedOn":null}"#

    /// - Parameters:
    ///   - rejectedWriteIndexes: 送った書き込みの、要求の中の位置。範囲の外として受け付けない
    ///   - pullPages: 取りに行くたびに、順に返す応答。使い切ったら最後のものを返し続ける
    static func ok(
        pushStatus: HTTPResponse.Status = .ok,
        rejectedWriteIndexes: Set<Int> = [],
        pullPages: [String] = [emptyPage]
    ) -> ClientTransportMock {
        let pulls = Pulls(pages: pullPages)
        return ClientTransportMock { request, body in
            if request.path == "/v1/sync/writes" {
                return pushResponse(
                    status: pushStatus, body: body, rejectedWriteIndexes: rejectedWriteIndexes)
            }
            return jsonResponse(status: .ok, json: pulls.next())
        }
    }

    static func error(_ error: any Error) -> ClientTransportMock {
        ClientTransportMock { _, _ in throw error }
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
        return try respond(request, bodyText)
    }

    private final class Pulls: @unchecked Sendable {
        private var pages: [String]

        init(pages: [String]) {
            self.pages = pages
        }

        func next() -> String {
            pages.count > 1 ? pages.removeFirst() : pages[0]
        }
    }

    private let respond: @Sendable (HTTPRequest, String?) throws -> (HTTPResponse, HTTPBody?)

    private init(
        respond: @escaping @Sendable (HTTPRequest, String?) throws -> (HTTPResponse, HTTPBody?)
    ) {
        self.respond = respond
    }

    private static func pushResponse(
        status: HTTPResponse.Status,
        body: String?,
        rejectedWriteIndexes: Set<Int>
    ) -> (HTTPResponse, HTTPBody?) {
        guard status == .ok else {
            return (HTTPResponse(status: status), nil)
        }
        let writes =
            (try? JSONSerialization.jsonObject(with: Data((body ?? "").utf8)) as? NSDictionary)?[
                "writes"
            ] as? [NSDictionary] ?? []
        let results = writes.enumerated().map { index, write in
            let writeId = write["id"] as? String ?? ""
            return rejectedWriteIndexes.contains(index)
                ? #"{"writeId":"\#(writeId)","result":"rejected","rejectionReason":"out_of_range"}"#
                : #"{"writeId":"\#(writeId)","result":"applied"}"#
        }
        return jsonResponse(status: .ok, json: #"{"results":[\#(results.joined(separator: ","))]}"#)
    }

    private static func jsonResponse(status: HTTPResponse.Status, json: String) -> (
        HTTPResponse, HTTPBody?
    ) {
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }
}
