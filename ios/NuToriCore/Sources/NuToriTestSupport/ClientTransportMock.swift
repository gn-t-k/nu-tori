public import Foundation
public import HTTPTypes
public import NuToriCore
public import OpenAPIRuntime

/// API のトランスポートの差し替え。送った要求を記録する
///
/// 作り方は、答え方ごとに `ok`（どの要求にも同じ答え）、`sync`（同期の書き込みと取得）、
/// `account`（サインインと削除）、`mealPhotos`（縮小版を取りに行く）、`error`（投げる）の5つ
public final class ClientTransportMock: ClientTransport, @unchecked Sendable {
    public private(set) var requests: [(request: HTTPRequest, body: String?)] = []

    /// 送り待ちを送った要求の本文。知らない種類の書き込みがあれば投げる
    public var pushBodies: [SentWritesBody] {
        get throws {
            try requests.filter { $0.request.path == "/v1/sync/writes" }.map {
                try SentWritesBody(json: $0.body ?? "")
            }
        }
    }

    /// 変更の取得の要求のクエリ
    public var pullQueries: [[String: String]] {
        get throws {
            try requests.filter { $0.request.path?.hasPrefix("/v1/sync/changes") == true }.map {
                guard
                    let components = URLComponents(
                        string: "https://api.example\($0.request.path ?? "")")
                else { throw URLError(.badURL) }
                return Dictionary(
                    uniqueKeysWithValues: (components.queryItems ?? []).map {
                        ($0.name, $0.value ?? "")
                    })
            }
        }
    }

    public static let emptyPage =
        #"{"changes":[],"hasMore":false,"nextAfterSequence":0,"startedOn":null}"#

    /// どの要求にも同じ状態コードと本文で答える
    public static func ok(status: HTTPResponse.Status = .ok, json: String? = nil)
        -> ClientTransportMock
    {
        ClientTransportMock { _, _ in
            guard let json else { return (HTTPResponse(status: status), nil) }
            return jsonResponse(status: status, json: json)
        }
    }

    /// 受け付けなかった書き込みに添える、サーバーの今の値の JSON（サーバーの API の `current`）
    public enum Current: Sendable {
        case absent
        /// 体重記録の削除の印
        case deleted(recordId: UUID)
        /// 体重記録の今の値
        case weightRecord(WeightRecord)
        /// 食事の削除の印
        case deletedMeal(mealId: UUID)

        var json: String {
            switch self {
            case .absent:
                #"{"status":"absent"}"#
            case .deleted(let recordId):
                """
                {"status":"deleted","change":{"kind":"weight_record_deletion",\
                "recordId":"\(recordId.uuidString)","record":{}}}
                """
            case .deletedMeal(let mealId):
                """
                {"status":"deleted","change":{"kind":"meal_deletion",\
                "recordId":"\(mealId.uuidString)","record":{}}}
                """
            case .weightRecord(let record):
                """
                {"status":"value","change":{"kind":"weight_record",\
                "recordId":"\(record.id.uuidString)",\
                "record":{"id":"\(record.id.uuidString)","weightKg":\(record.kilograms),\
                "measuredAt":\(Int((record.instant.timeIntervalSince1970 * 1000).rounded())),\
                "timeZone":"\(record.timeZone.identifier)","version":\(record.version)}}}
                """
            }
        }
    }

    /// 書き込みには受け付けたか断ったかを送った順に返し、取得には `pullPages` を1ページずつ返す。
    /// 断った書き込みには、`currents` にあれば、サーバーの今の値を添える
    public static func sync(
        pushStatus: HTTPResponse.Status = .ok,
        rejectedWriteIndexes: Set<Int> = [],
        currents: [Int: Current] = [:],
        pullPages: [String] = [emptyPage]
    ) -> ClientTransportMock {
        let pulls = Pulls(pages: pullPages)
        return ClientTransportMock { request, body in
            if request.path == "/v1/sync/writes" {
                return try pushResponse(
                    status: pushStatus, body: body, rejectedWriteIndexes: rejectedWriteIndexes,
                    currents: currents)
            }
            return jsonResponse(status: .ok, json: pulls.next())
        }
    }

    public static func account(
        startStatus: HTTPResponse.Status = .created,
        accountId: String = "account-1",
        deleteStatus: HTTPResponse.Status = .noContent,
        onRequest: @escaping @Sendable (String) -> Void = { _ in }
    ) -> ClientTransportMock {
        ClientTransportMock { request, _ in
            let path = request.path ?? ""
            onRequest(path)
            switch path {
            case "/v1/sessions" where startStatus == .created:
                return jsonResponse(
                    status: .created,
                    json: #"{"sessionToken":"session-2","accountId":"\#(accountId)"}"#)
            case "/v1/sessions":
                return (HTTPResponse(status: startStatus), nil)
            case "/v1/account":
                return (HTTPResponse(status: deleteStatus), nil)
            default:
                return (HTTPResponse(status: .notFound), nil)
            }
        }
    }

    /// 縮小版を取りに行く要求に、`photos` にある写真は JPEG で、無い写真は 404 で答える
    public static func mealPhotos(_ photos: [UUID: Data]) -> ClientTransportMock {
        ClientTransportMock { request, _ in
            let path = request.path ?? ""
            let prefix = "/v1/meal-photos/"
            guard path.hasPrefix(prefix),
                let photoId = UUID(uuidString: String(path.dropFirst(prefix.count))),
                let photo = photos[photoId]
            else {
                return (HTTPResponse(status: .notFound), nil)
            }
            var response = HTTPResponse(status: .ok)
            response.headerFields[.contentType] = "image/jpeg"
            return (response, HTTPBody(photo))
        }
    }

    public static func error(_ error: any Error) -> ClientTransportMock {
        ClientTransportMock { _, _ in throw error }
    }

    @concurrent public func send(
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
        rejectedWriteIndexes: Set<Int>,
        currents: [Int: Current]
    ) throws -> (HTTPResponse, HTTPBody?) {
        guard status == .ok else {
            return (HTTPResponse(status: status), nil)
        }
        let writes = try SentWritesBody(json: body ?? "").writes
        let results = writes.enumerated().map { index, write in
            let writeId = write.id
            guard rejectedWriteIndexes.contains(index) else {
                return #"{"writeId":"\#(writeId)","result":"applied"}"#
            }
            let current = currents[index].map { #","current":\#($0.json)"# } ?? ""
            return
                #"{"writeId":"\#(writeId)","result":"rejected","rejectionReason":"out_of_range"\#(current)}"#
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
