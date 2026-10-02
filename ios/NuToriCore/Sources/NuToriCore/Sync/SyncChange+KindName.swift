public import NuToriAPI

extension SyncChange {
    /// この変更がどの記録の種類のものか。知らない種類（`.unknown`）は nil。
    /// 全部の case を並べる switch はここ1か所にする。case を足したら、ここに種類を書く。
    /// 各種類は、自分の変更かをこれと自分の名前で決め、自分の case を `if case` で取り出す
    public var kindName: RecordKindName? {
        switch self {
        case .weightRecord, .weightRecordDeletion: .weightRecord
        case .accountSettings: .accountSettings
        case .dish, .dishDeletion: .dish
        case .ingredient, .ingredientDeletion: .ingredient
        case .meal, .mealDeletion: .meal
        case .mealEstimationStatus, .mealEstimationStatusDeletion: .mealEstimationStatus
        case .notice, .noticeRemoval: .notice
        case .usualWeighingTime: .usualWeighingTime
        case .weightTrend, .weightTrendAbsence: .weightTrend
        case .unknown: nil
        }
    }
}
