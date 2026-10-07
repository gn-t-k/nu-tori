public import Foundation
public import HTTPTypes
public import NuToriAPI
public import NuToriCore
public import OpenAPIRuntime

/// API のトランスポートの差し替え。送った要求を記録する
///
/// 作り方は、答え方ごとに `ok`（どの要求にも同じ答え）、`sync`（同期の書き込みと取得）、
/// `account`（サインインと削除）、`mealPhotos`（縮小版を取りに行く）、`error`（投げる）の5つ
public final class ClientTransportMock: ClientTransport, @unchecked Sendable {
    public private(set) var requests: [(request: HTTPRequest, body: String?)] = []

    /// 送り待ちを送った要求の本文。知らない種類の書き込みがあれば投げる
    public var pushBodies: [SentSyncWrites] {
        get throws {
            try requests.filter { $0.request.path == "/v1/sync/writes" }.map {
                try Self.sentWrites($0.body)
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
        /// 答えていない知らせの今の値
        case unansweredNotice(Notice)
        /// 食事の今の値
        case meal(SyncedMeal)
        /// 料理の今の値
        case dish(SyncedDish)
        /// 材料の今の値
        case ingredient(SyncedIngredient)
        /// 料理の削除の印
        case deletedDish(dishId: UUID)
        /// 材料の削除の印（推定し直しで置き換わった材料も、削除の印で返る）
        case deletedIngredient(ingredientId: UUID)

        /// 偽の同期サーバーと同じ道で、線上の形にする
        var syncWriteCurrent: SyncWriteResult.Current {
            switch self {
            case .absent: .absent
            case .deleted(let recordId): .deleted(.weightRecordDeletion(recordId: recordId))
            case .deletedMeal(let mealId): .deleted(.mealDeletion(mealId: mealId))
            case .meal(let meal): .value(.meal(meal))
            case .dish(let dish): .value(.dish(dish))
            case .ingredient(let ingredient): .value(.ingredient(ingredient))
            case .deletedDish(let dishId): .deleted(.dishDeletion(dishId: dishId))
            case .deletedIngredient(let ingredientId):
                .deleted(.ingredientDeletion(ingredientId: ingredientId))
            case .unansweredNotice(let notice):
                .value(
                    .notice(
                        SyncedNotice(
                            id: notice.id, noticeType: .missedWeightRecord,
                            issuedAt: notice.issuedAt, timeZone: notice.timeZone,
                            targetOn: notice.targetDay.yearMonthDay, response: nil)))
            case .weightRecord(let record):
                .value(
                    .weightRecord(
                        SyncedWeightRecord(
                            id: record.id, weightKilograms: record.kilograms,
                            measuredAt: record.instant, timeZone: record.timeZone,
                            version: record.version, imported: nil)))
            }
        }
    }

    /// 書き込みには受け付けたか断ったかを送った順に返し、取得には `pullPages` を1ページずつ返す（`pullStatus` が 200 でなければ、本文の無いその状態コード）。
    /// 断った書き込みには、`currents` にあれば、サーバーの今の値を添える。断った理由は、`rejectionReasons` に無ければ `out_of_range`
    public static func sync(
        pushStatus: HTTPResponse.Status = .ok,
        rejectedWriteIndexes: Set<Int> = [],
        currents: [Int: Current] = [:],
        rejectionReasons: [Int: String] = [:],
        pullPages: [String] = [emptyPage],
        pullStatus: HTTPResponse.Status = .ok
    ) -> ClientTransportMock {
        let pulls = Pulls(pages: pullPages)
        return ClientTransportMock { request, body in
            if request.path == "/v1/sync/writes" {
                return try pushResponse(
                    status: pushStatus, body: body, rejectedWriteIndexes: rejectedWriteIndexes,
                    currents: currents, rejectionReasons: rejectionReasons)
            }
            guard pullStatus == .ok else { return (HTTPResponse(status: pullStatus), nil) }
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
        currents: [Int: Current],
        rejectionReasons: [Int: String]
    ) throws -> (HTTPResponse, HTTPBody?) {
        guard status == .ok else {
            return (HTTPResponse(status: status), nil)
        }
        let writes = try sentWrites(body).writes
        let results = try writes.enumerated().map { index, write in
            let writeId = write.writeId.canonicalString
            guard rejectedWriteIndexes.contains(index) else {
                return #"{"writeId":"\#(writeId)","result":"applied"}"#
            }
            let current =
                try currents[index].map { #","current":\#(try $0.syncWriteCurrent.json())"# } ?? ""
            let reason = rejectionReasons[index] ?? "out_of_range"
            return
                #"{"writeId":"\#(writeId)","result":"rejected","rejectionReason":"\#(reason)"\#(current)}"#
        }
        return jsonResponse(status: .ok, json: #"{"results":[\#(results.joined(separator: ","))]}"#)
    }

    private static func sentWrites(_ body: String?) throws -> SentSyncWrites {
        guard let body else { throw MissingBodyError() }
        return try SentSyncWrites(json: Data(body.utf8))
    }

    private struct MissingBodyError: Error {}

    private static func jsonResponse(status: HTTPResponse.Status, json: String) -> (
        HTTPResponse, HTTPBody?
    ) {
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }
}
