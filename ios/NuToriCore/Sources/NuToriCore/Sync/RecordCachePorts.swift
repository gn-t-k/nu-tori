/// 箱のキャッシュ（アプリでは `ModelContext`、メモリの箱では `RecordCacheMock`）から、記録の種類ごとのキャッシュの口を取り出す。
/// キャッシュの作り方（SwiftData とメモリ）ごとに1つ書く。登録簿の並びは `RecordKindRegistry.init(ports:)` に1回だけ書き、これで差し替える。
/// 種類を足すと、ここに足すまで、どちらの作り方もコンパイルが止まる
public protocol RecordCachePorts<Cache>: Sendable {
    associatedtype Cache

    func accountSettings(in cache: Cache) -> AccountSettingsSyncKind.Cache

    func aiUtterance(in cache: Cache) -> AiUtteranceSyncing.Cache

    func dailyGuide(in cache: Cache) -> DailyGuideSyncing.Cache

    func dish(in cache: Cache) -> DishSyncing.Cache

    func dishEstimationStatus(in cache: Cache) -> DishEstimationStatusSyncing.Cache

    func expenditureEstimate(in cache: Cache) -> ExpenditureEstimateSyncing.Cache

    func goal(in cache: Cache) -> GoalSyncing.Cache

    func ingredient(in cache: Cache) -> IngredientSyncing.Cache

    func meal(in cache: Cache) -> MealSyncing.Cache

    func mealEstimationStatus(in cache: Cache) -> MealEstimationStatusSyncing.Cache

    func notice(in cache: Cache) -> NoticeSyncing.Cache

    func sentText(in cache: Cache) -> SentTextSyncing.Cache

    func sentTextStatus(in cache: Cache) -> SentTextStatusSyncing.Cache

    func usualWeighingTime(in cache: Cache) -> UsualWeighingTimeSyncing.Cache

    func weightRecord(in cache: Cache) -> WeightRecordSyncing.Cache

    func weightTrend(in cache: Cache) -> WeightTrendSyncing.Cache
}

extension RecordKindRegistry {
    /// 記録の種類の登録簿。名前の順に、手で1行ずつ書く。種類ごとのキャッシュの口は `ports` が取り出す
    public init(ports: some RecordCachePorts<Cache>) {
        self.init([
            PortedRecordKind(AccountSettingsSyncKind()) { ports.accountSettings(in: $0) },
            PortedRecordKind(AiUtteranceSyncing()) { ports.aiUtterance(in: $0) },
            PortedRecordKind(DailyGuideSyncing()) { ports.dailyGuide(in: $0) },
            PortedRecordKind(DishSyncing()) { ports.dish(in: $0) },
            PortedRecordKind(DishEstimationStatusSyncing()) { ports.dishEstimationStatus(in: $0) },
            PortedRecordKind(ExpenditureEstimateSyncing()) { ports.expenditureEstimate(in: $0) },
            PortedRecordKind(GoalSyncing()) { ports.goal(in: $0) },
            PortedRecordKind(IngredientSyncing()) { ports.ingredient(in: $0) },
            PortedRecordKind(MealSyncing()) { ports.meal(in: $0) },
            PortedRecordKind(MealEstimationStatusSyncing()) { ports.mealEstimationStatus(in: $0) },
            PortedRecordKind(NoticeSyncing()) { ports.notice(in: $0) },
            PortedRecordKind(SentTextSyncing()) { ports.sentText(in: $0) },
            PortedRecordKind(SentTextStatusSyncing()) { ports.sentTextStatus(in: $0) },
            PortedRecordKind(UsualWeighingTimeSyncing()) { ports.usualWeighingTime(in: $0) },
            PortedRecordKind(WeightRecordSyncing()) { ports.weightRecord(in: $0) },
            PortedRecordKind(WeightTrendSyncing()) { ports.weightTrend(in: $0) },
        ])
    }
}
