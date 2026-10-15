public import Foundation

/// キャッシュの記録を読む口。同期の働きとヘルスケアの取り込みが、今の値を見て判断するために使う。
/// 書く口は、箱の `apply` の1つだけ
public protocol RecordCacheReading: Sendable {
    /// 登録簿から種類 `Syncing` のキャッシュの口（`KeyedRecordCache`・`SingleRecordCache`）を引き、`body` で読む。
    /// 登録簿に無い種類は `UnknownRecordKindError.notRegistered` を投げる
    func read<Syncing: CacheApplying, Value: Sendable>(
        _ kind: Syncing.Type,
        _ body: @Sendable (Syncing.Cache) throws -> Value
    ) async throws -> Value
}

/// よく読む形の短い呼び方。種類ごとの読み方は、ここに1回だけ書く
extension RecordCacheReading {
    public func weightRecord(id: UUID) async throws -> WeightRecord? {
        try await read(WeightRecordSyncing.self) { try $0.record(id: id) }
    }

    public func weightRecords() async throws -> [WeightRecord] {
        try await read(WeightRecordSyncing.self) { try $0.all() }
    }

    public func accountSettings() async throws -> AccountSettings? {
        try await read(AccountSettingsSyncKind.self) { try $0.read() }
    }

    /// 食事の ID ごとの推定の状態。食事より先に届いた状態も含む
    public func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus] {
        try await read(MealEstimationStatusSyncing.self) {
            byParentId(try $0.all()) { ($0.mealId, $0.status) }
        }
    }

    public func meals() async throws -> [Meal] {
        try await read(MealSyncing.self) { try $0.all() }
    }

    /// 親の食事がまだ届いていない料理も含む
    public func dishes() async throws -> [Dish] {
        try await read(DishSyncing.self) { try $0.all() }
    }

    /// 料理の ID ごとの推定の状態。料理より先に届いた状態も含む
    public func dishEstimationStatuses() async throws -> [UUID: DishEstimationStatus] {
        try await read(DishEstimationStatusSyncing.self) {
            byParentId(try $0.all()) { ($0.dishId, $0.status) }
        }
    }

    /// 親の料理がまだ届いていない材料も含む
    public func ingredients() async throws -> [Ingredient] {
        try await read(IngredientSyncing.self) { try $0.all() }
    }

    /// 答えた知らせも含む
    public func notices() async throws -> [Notice] {
        try await read(NoticeSyncing.self) { try $0.all() }
    }

    /// 閉じた目標も含む
    public func goals() async throws -> [Goal] {
        try await read(GoalSyncing.self) { try $0.all() }
    }

    /// まだ学んでいなければ nil
    public func usualWeighingTime() async throws -> UsualWeighingTime? {
        try await read(UsualWeighingTimeSyncing.self) { try $0.read() }
    }

    public func sentTexts() async throws -> [SentText] {
        try await read(SentTextSyncing.self) { try $0.all() }
    }

    /// 送った文章の ID ごとの状態。送った文章より先に届いた状態も含む
    public func sentTextStatuses() async throws -> [UUID: SentTextStatus] {
        try await read(SentTextStatusSyncing.self) {
            byParentId(try $0.all()) { ($0.sentTextId, $0.status) }
        }
    }
}

/// 親の ID で引く状態を、親の ID ごとにまとめる。同じ親の状態が重なっていたら、あとの状態を取る
private func byParentId<Record, Status>(
    _ records: [Record],
    _ parentIdAndStatus: (Record) -> (UUID, Status)
) -> [UUID: Status] {
    Dictionary(records.map(parentIdAndStatus), uniquingKeysWith: { _, last in last })
}
