/// 記録の種類ごとの符号化の表。種類を足したら、`coding(of:)` に1行足す（サーバーの列挙に足した名前がここに無いと、コンパイルが止める）
enum RecordKindWireCodings {
    static let all: [any RecordKindWireCoding] =
        Components.Schemas.RecordKindName.allCases.map(coding(of:))

    static func coding(of kind: Components.Schemas.RecordKindName) -> any RecordKindWireCoding {
        switch kind {
        case .accountSettings: AccountSettingsWireCoding()
        case .aiUtterance: AiUtteranceWireCoding()
        case .dailyGuide: DailyGuideWireCoding()
        case .dish: DishWireCoding()
        case .dishEstimationStatus: DishEstimationStatusWireCoding()
        case .expenditureEstimate: ExpenditureEstimateWireCoding()
        case .goal: GoalWireCoding()
        case .ingredient: IngredientWireCoding()
        case .meal: MealWireCoding()
        case .mealEstimationStatus: MealEstimationStatusWireCoding()
        case .notice: NoticeWireCoding()
        case .sentText: SentTextWireCoding()
        case .sentTextStatus: SentTextStatusWireCoding()
        case .usualWeighingTime: UsualWeighingTimeWireCoding()
        case .weightRecord: WeightRecordWireCoding()
        case .weightTrend: WeightTrendWireCoding()
        }
    }

    /// 線上の kind（種類の名前に形の接尾辞を付けたもの）の変更を読む。
    /// 知らない kind と読めない中身は、古い版のアプリの同期が止まらないように `.unknown` で持つ
    static func change(wireKind: String, recordId: String, record: some Encodable) -> SyncChange {
        guard let reader = readers[wireKind] else { return .unknown(kind: wireKind) }
        return reader.coding.change(reader.form, recordId: recordId, record: record)
            ?? .unknown(kind: wireKind)
    }

    private static let readers: [String: Reader] = Dictionary(
        uniqueKeysWithValues: all.flatMap { coding in
            SyncChange.WireForm.allCases.map { form in
                (coding.kind.rawValue + form.kindSuffix, Reader(coding: coding, form: form))
            }
        })

    private struct Reader {
        let coding: any RecordKindWireCoding
        let form: SyncChange.WireForm
    }
}
