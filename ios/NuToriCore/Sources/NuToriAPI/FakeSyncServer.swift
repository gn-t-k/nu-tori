#if DEBUG
    public import Foundation
    public import HTTPTypes
    public import OpenAPIRuntime
    import Synchronization

    /// メモリ上の偽の同期サーバー。UI テストのアプリが、サーバーにつながずに使うトランスポート
    ///
    /// 種類ごとの記録と通し番号を持ち、届いた書き込みを当てて、取りに行かれたら前の通し番号より後の変更を返す。
    /// 場面ごとの違いは、初めに置く記録と方針（`Scenario`）だけで出す。書き込みは `SentSyncWrites` で読む
    public final class FakeSyncServer: ClientTransport, Sendable {
        /// セッションを始める要求に返すトークン
        public static let sessionToken = "stub-session"
        /// セッションを始める要求に返すアカウント ID
        public static let accountId = "stub-account"

        private let scenario: Scenario
        private let writePolicies: [Components.Schemas.RecordKindName: WritePolicy]
        private let ledger: Mutex<Ledger>

        public init(_ scenario: Scenario) {
            self.scenario = scenario
            writePolicies = Dictionary(
                uniqueKeysWithValues: scenario.writePolicies.map { name, policy in
                    guard let kind = Components.Schemas.RecordKindName(rawValue: name) else {
                        preconditionFailure("サーバーの知らない記録の種類 \(name) に方針を置いた")
                    }
                    return (kind, policy)
                })
            var ledger = Ledger()
            for record in scenario.records {
                ledger.put(record)
            }
            self.ledger = Mutex(ledger)
        }

        @concurrent public func send(
            _ request: HTTPRequest,
            body: HTTPBody?,
            baseURL: URL,
            operationID: String
        ) async throws -> (HTTPResponse, HTTPBody?) {
            switch scenario.connection {
            case .online:
                break
            case .offline:
                throw URLError(.notConnectedToInternet)
            case .appBuildUnsupported:
                return (
                    HTTPResponse(status: .init(code: AppBuildVerdict.unsupportedStatusCode)), nil
                )
            }
            switch operationID {
            case Operations.CreateSession.id:
                return try json(
                    .created,
                    Operations.CreateSession.Output.Created.Body.JsonPayload(
                        sessionToken: Self.sessionToken, accountId: Self.accountId))
            case Operations.DeleteAccount.id:
                return (HTTPResponse(status: scenario.accountDeletion.status), nil)
            case Operations.PushSyncWrites.id:
                return try json(.ok, try await push(body))
            case Operations.PullSyncChanges.id:
                return try json(.ok, try await pull(request))
            default:
                return (HTTPResponse(status: .notFound), nil)
            }
        }

        /// 場面。初めに置く記録と、要求ごとの方針
        public struct Scenario: Sendable {
            /// 初めに置く記録。並びの順に通し番号を振る
            public let records: [SyncChange]
            /// 取得の応答に載せる使い始めた日（YYYY-MM-DD）
            public let startedOn: String
            public let connection: Connection
            public let pull: Pull
            /// 書き込みが当たる記録の種類ごとの方針。鍵はサーバーの種類の名前（端末の `RecordKindName.serverName`）。
            /// 無い種類は受け付ける
            public let writePolicies: [String: WritePolicy]
            public let accountDeletion: AccountDeletion
            /// 推定を終えた食事に、その食事の ID から作る料理と材料
            public let estimatedDishes: @Sendable (UUID) -> [SyncChange]

            public init(
                records: [SyncChange],
                startedOn: String,
                connection: Connection = .online,
                pull: Pull = .answers,
                writePolicies: [String: WritePolicy] = [:],
                accountDeletion: AccountDeletion = .deletes,
                estimatedDishes: @escaping @Sendable (UUID) -> [SyncChange] = { _ in [] }
            ) {
                self.records = records
                self.startedOn = startedOn
                self.connection = connection
                self.pull = pull
                self.writePolicies = writePolicies
                self.accountDeletion = accountDeletion
                self.estimatedDishes = estimatedDishes
            }
        }

        public enum Connection: Sendable {
            case online
            /// どの要求も届かない
            case offline
            /// どの要求にも 426 を返す（最低バージョンより古いビルド）
            case appBuildUnsupported
        }

        public enum Pull: Sendable {
            case answers
            /// 取得を終えない（初回の取得の読み込み中を見るため）
            case hangs
        }

        public enum WritePolicy: Sendable {
            case apply
            /// 当てずに断り、その記録の今の値を添える。理由は画面の文言に出ないので、範囲の外に決める
            case reject
            /// その種類を含む要求は届かない
            case unreachable
        }

        public enum AccountDeletion: Sendable {
            case deletes
            case rateLimited
            case sessionExpired

            fileprivate var status: HTTPResponse.Status {
                switch self {
                case .deletes: .noContent
                case .rateLimited: .tooManyRequests
                case .sessionExpired: .unauthorized
                }
            }
        }

        private func push(_ body: HTTPBody?) async throws
            -> Operations.PushSyncWrites.Output.Ok.Body.JsonPayload
        {
            guard let body else { throw MissingBodyError() }
            let writes = try SentSyncWrites(json: try await Data(collecting: body, upTo: 1_048_576))
                .writes
            let rejects = try writes.map { write in
                switch writePolicies[write.recordKey.kind] ?? .apply {
                case .apply: false
                case .reject: true
                case .unreachable: throw URLError(.notConnectedToInternet)
                }
            }
            let results = try ledger.withLock { ledger in
                for (write, rejected) in zip(writes, rejects) where !rejected {
                    ledger.apply(write)
                }
                // サーバーと同じく、今の値は要求の書き込みを全部当て終えた時点のもの
                return try zip(writes, rejects).map { write, rejected in
                    rejected
                        ? Components.Schemas.SyncWriteResult(
                            writeId: write.writeId.uuidString, result: "rejected",
                            rejectionReason: "out_of_range",
                            current: try .init(ledger.current(of: write.recordKey)))
                        : Components.Schemas.SyncWriteResult(
                            writeId: write.writeId.uuidString, result: "applied")
                }
            }
            return .init(results: results)
        }

        private func pull(_ request: HTTPRequest) async throws
            -> Operations.PullSyncChanges.Output.Ok.Body.JsonPayload
        {
            switch scenario.pull {
            case .hangs:
                // テストが見ているあいだ、取得を終えない
                try await Task.sleep(for: .seconds(60))
                throw URLError(.timedOut)
            case .answers:
                let afterSequence = Self.afterSequence(of: request)
                let entries = ledger.withLock {
                    $0.pull(after: afterSequence, estimatedDishes: scenario.estimatedDishes)
                }
                return .init(
                    changes: try entries.map {
                        try Components.Schemas.SyncChange($0.change, sequence: $0.sequence)
                    },
                    hasMore: false,
                    nextAfterSequence: entries.last?.sequence ?? afterSequence,
                    startedOn: scenario.startedOn
                )
            }
        }

        private static func afterSequence(of request: HTTPRequest) -> Int {
            URLComponents(string: request.path ?? "")?.queryItems?
                .first { $0.name == "afterSequence" }?.value.flatMap(Int.init) ?? 0
        }

        private func json(_ status: HTTPResponse.Status, _ payload: some Encodable) throws -> (
            HTTPResponse, HTTPBody?
        ) {
            var response = HTTPResponse(status: status)
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(try JSONEncoder().encode(payload)))
        }

        struct MissingBodyError: Error {}

        /// 記録の種類と ID の組。削除の印は、消した記録と同じ組に置く
        struct RecordKey: Hashable {
            let kind: Components.Schemas.RecordKindName
            let id: String
        }

        /// 記録の鍵ごとの最後の変更と、その通し番号
        private struct Ledger {
            private var sequence = 0
            private var entries: [RecordKey: Entry] = [:]
            /// 推定中を返した食事。次に取りに行かれたら推定を終える
            private var estimatingMealIds: [UUID] = []

            struct Entry {
                let sequence: Int
                let change: SyncChange
            }

            mutating func put(_ change: SyncChange) {
                sequence += 1
                entries[change.recordKey] = Entry(sequence: sequence, change: change)
            }

            func current(of key: RecordKey) -> SyncWriteResult.Current {
                guard let change = entries[key]?.change else { return .absent }
                return change.isDeletion ? .deleted(change) : .value(change)
            }

            mutating func pull(
                after afterSequence: Int, estimatedDishes: (UUID) -> [SyncChange]
            ) -> [Entry] {
                for mealId in estimatingMealIds {
                    put(.mealEstimationStatus(.init(mealId: mealId, status: .estimated)))
                    for change in estimatedDishes(mealId) {
                        put(change)
                    }
                }
                let page = entries.values.filter { $0.sequence > afterSequence }
                    .sorted { $0.sequence < $1.sequence }
                estimatingMealIds = page.compactMap {
                    guard case .mealEstimationStatus(let status) = $0.change,
                        status.status == .estimating
                    else { return nil }
                    return status.mealId
                }
                return page
            }

            /// 届いた値をそのまま置く。サーバーの当て方の決まり（版の比べ方、消したときに連れて消すもの）は真似ない。
            /// 作る書き込みだけは、送り直されても記録を作り直さない
            mutating func apply(_ write: SyncWrite) {
                switch write {
                case .createWeightRecord(_, let record):
                    guard entries[write.recordKey] == nil else { return }
                    put(
                        .weightRecord(
                            SyncedWeightRecord(
                                id: record.id, weightKilograms: record.weightKilograms,
                                measuredAt: record.measuredAt, timeZone: record.timeZone,
                                version: 1, imported: record.imported)))
                case .updateWeightRecord(_, let correction):
                    let current = weightRecord(write.recordKey)
                    put(
                        .weightRecord(
                            SyncedWeightRecord(
                                id: correction.id, weightKilograms: correction.weightKilograms,
                                measuredAt: correction.measuredAt, timeZone: correction.timeZone,
                                version: correction.version, imported: current?.imported)))
                case .sourceDeletedWeightRecord(_, let weightRecordId):
                    put(.weightRecordDeletion(recordId: weightRecordId))
                case .updateAccountSettings(_, let settings):
                    put(.accountSettings(settings))
                case .createMeal(_, let meal):
                    guard entries[write.recordKey] == nil else { return }
                    put(.meal(meal))
                    put(.mealEstimationStatus(.init(mealId: meal.id, status: .estimating)))
                case .deleteMeal(_, let mealId):
                    put(.mealDeletion(mealId: mealId))
                    estimatingMealIds.removeAll { $0 == mealId }
                case .deleteDish(_, let dishId):
                    put(.dishDeletion(dishId: dishId))
                case .createNotice(_, let notice):
                    guard entries[write.recordKey] == nil else { return }
                    put(
                        .notice(
                            SyncedNotice(
                                id: notice.id, noticeType: notice.noticeType,
                                issuedAt: notice.issuedAt, timeZone: notice.timeZone,
                                targetOn: notice.targetOn, response: nil)))
                case .respondNotice(_, _, let response):
                    guard case .notice(let notice) = entries[write.recordKey]?.change else {
                        return
                    }
                    put(
                        .notice(
                            SyncedNotice(
                                id: notice.id, noticeType: notice.noticeType,
                                issuedAt: notice.issuedAt, timeZone: notice.timeZone,
                                targetOn: notice.targetOn, response: response)))
                }
            }

            private func weightRecord(_ key: RecordKey) -> SyncedWeightRecord? {
                guard case .weightRecord(let record) = entries[key]?.change else { return nil }
                return record
            }
        }
    }
#endif
