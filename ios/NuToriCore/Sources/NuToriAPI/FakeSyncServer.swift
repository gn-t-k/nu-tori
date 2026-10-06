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
            /// 推定し直し（料理を足した・名前を直した）を終えた料理に、料理の ID と名前から作る量と材料。nil なら材料を推定できない（料理なし）
            public let estimateDish: @Sendable (_ dishId: UUID, _ name: String) -> DishEstimate?

            public init(
                records: [SyncChange],
                startedOn: String,
                connection: Connection = .online,
                pull: Pull = .answers,
                writePolicies: [String: WritePolicy] = [:],
                accountDeletion: AccountDeletion = .deletes,
                estimatedDishes: @escaping @Sendable (UUID) -> [SyncChange] = { _ in [] },
                estimateDish:
                    @escaping @Sendable (_ dishId: UUID, _ name: String) -> DishEstimate? =
                    { _, _ in nil }
            ) {
                self.records = records
                self.startedOn = startedOn
                self.connection = connection
                self.pull = pull
                self.writePolicies = writePolicies
                self.accountDeletion = accountDeletion
                self.estimatedDishes = estimatedDishes
                self.estimateDish = estimateDish
            }
        }

        /// 推定し直しで当てる、料理の量と材料。料理の量を直してあれば、量は当てず材料だけを当てる
        public struct DishEstimate: Sendable {
            public let quantity: SyncedDish.Quantity
            public let ingredients: [SyncedIngredient]

            public init(quantity: SyncedDish.Quantity, ingredients: [SyncedIngredient]) {
                self.quantity = quantity
                self.ingredients = ingredients
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
                    $0.pull(
                        after: afterSequence, estimatedDishes: scenario.estimatedDishes,
                        estimateDish: scenario.estimateDish)
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
            /// 推定中を返した料理。次に取りに行かれたら推定し直しを終える
            private var estimatingDishIds: [UUID] = []

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
                after afterSequence: Int, estimatedDishes: (UUID) -> [SyncChange],
                estimateDish: (UUID, String) -> DishEstimate?
            ) -> [Entry] {
                for mealId in estimatingMealIds {
                    put(.mealEstimationStatus(.init(mealId: mealId, status: .estimated)))
                    for change in estimatedDishes(mealId) {
                        put(change)
                    }
                }
                for dishId in estimatingDishIds {
                    reestimate(dishId: dishId, estimateDish: estimateDish)
                }
                let page = entries.values.filter { $0.sequence > afterSequence }
                    .sorted { $0.sequence < $1.sequence }
                estimatingMealIds = page.compactMap {
                    guard case .mealEstimationStatus(let status) = $0.change,
                        status.status == .estimating
                    else { return nil }
                    return status.mealId
                }
                estimatingDishIds = page.compactMap {
                    guard case .dishEstimationStatus(let status) = $0.change,
                        status.status == .estimating
                    else { return nil }
                    return status.dishId
                }
                return page
            }

            /// 前の材料を削除の印にし、推定した量（量を直してあれば直した量のまま）と材料を当てる。推定できなければ料理なしにする
            private mutating func reestimate(
                dishId: UUID, estimateDish: (UUID, String) -> DishEstimate?
            ) {
                guard case .dish(let dish) = entries[.init(kind: .dish, id: dishId)]?.change else {
                    return
                }
                for ingredient in ingredients(ofDish: dishId) {
                    put(.ingredientDeletion(ingredientId: ingredient.id))
                }
                guard let estimate = estimateDish(dishId, dish.name) else {
                    put(.dishEstimationStatus(.init(dishId: dishId, status: .noDishes)))
                    return
                }
                let quantity =
                    dish.quantity?.source == .corrected ? dish.quantity : estimate.quantity
                put(.dish(dish.replacing(name: dish.name, quantity: quantity)))
                for ingredient in estimate.ingredients {
                    put(.ingredient(ingredient))
                }
                put(.dishEstimationStatus(.init(dishId: dishId, status: .estimated)))
            }

            /// 料理の今の材料（削除の印を除く）を、置いた順に
            private func ingredients(ofDish dishId: UUID) -> [SyncedIngredient] {
                entries.values.sorted { $0.sequence < $1.sequence }.compactMap {
                    guard case .ingredient(let ingredient) = $0.change,
                        ingredient.dishId == dishId
                    else { return nil }
                    return ingredient
                }
            }

            /// 量が今と違えば直した量にし、比例させた材料の量を当てる。名前が今と違えば、推定し直しを始める
            private mutating func apply(_ correction: DishCorrection) {
                guard
                    case .dish(let dish) = entries[.init(kind: .dish, id: correction.id)]?.change
                else { return }
                let quantity: SyncedDish.Quantity? =
                    if let value = correction.quantity?.value, let current = dish.quantity,
                        value != current.value
                    {
                        .init(value: value, unit: current.unit, source: .corrected)
                    } else {
                        dish.quantity
                    }
                let renamed = correction.name != dish.name
                guard renamed || quantity != dish.quantity else { return }
                put(.dish(dish.replacing(name: correction.name, quantity: quantity)))
                for proportioned in correction.quantity?.proportionedIngredients ?? [] {
                    let key = RecordKey(kind: .ingredient, id: proportioned.ingredientId)
                    guard case .ingredient(let ingredient) = entries[key]?.change,
                        ingredient.quantity != proportioned.quantity
                    else { continue }
                    // 比例させた材料の量の出どころは、推定したまま
                    put(
                        .ingredient(
                            ingredient.replacing(
                                quantity: proportioned.quantity, source: ingredient.quantitySource)
                        ))
                }
                if renamed {
                    put(.dishEstimationStatus(.init(dishId: dish.id, status: .estimating)))
                }
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
                case .updateMeal(_, _, let eatenAt):
                    guard case .meal(let meal) = entries[write.recordKey]?.change else { return }
                    put(
                        .meal(
                            SyncedMeal(
                                id: meal.id, eatenAt: eatenAt,
                                eatenUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                                sentAt: meal.sentAt, sentTimeZone: meal.sentTimeZone,
                                entryMethod: meal.entryMethod, photoIds: meal.photoIds)))
                case .deleteMeal(_, let mealId):
                    put(.mealDeletion(mealId: mealId))
                    estimatingMealIds.removeAll { $0 == mealId }
                case .deleteDish(_, let dishId):
                    put(.dishDeletion(dishId: dishId))
                    for ingredient in ingredients(ofDish: dishId) {
                        put(.ingredientDeletion(ingredientId: ingredient.id))
                    }
                    if case .dishEstimationStatus = entries[
                        .init(kind: .dishEstimationStatus, id: dishId)]?.change
                    {
                        put(.dishEstimationStatusDeletion(dishId: dishId))
                    }
                    estimatingDishIds.removeAll { $0 == dishId }
                case .createDish(_, let newDish):
                    guard entries[write.recordKey] == nil else { return }
                    put(
                        .dish(
                            SyncedDish(
                                id: newDish.id, mealId: newDish.mealId, name: newDish.name,
                                quantity: nil, positionInMeal: newDish.positionInMeal, version: 1)))
                    put(.dishEstimationStatus(.init(dishId: newDish.id, status: .estimating)))
                case .updateDish(_, let correction):
                    apply(correction)
                case .updateIngredient(_, _, let quantity):
                    guard case .ingredient(let ingredient) = entries[write.recordKey]?.change,
                        ingredient.quantity != quantity
                    else { return }
                    put(.ingredient(ingredient.replacing(quantity: quantity, source: .corrected)))
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

    extension SyncedDish {
        /// 版を1つ上げる
        fileprivate func replacing(name: String, quantity: Quantity?) -> SyncedDish {
            SyncedDish(
                id: id, mealId: mealId, name: name, quantity: quantity,
                positionInMeal: positionInMeal, version: version + 1)
        }
    }

    extension SyncedIngredient {
        fileprivate func replacing(quantity: Double, source: SyncedQuantitySource)
            -> SyncedIngredient
        {
            SyncedIngredient(
                id: id, dishId: dishId, name: name, quantity: quantity, quantitySource: source,
                unit: unit, edibleGramsPerUnit: edibleGramsPerUnit, positionInDish: positionInDish,
                nutrientSource: nutrientSource, nutrients: nutrients)
        }
    }
#endif
