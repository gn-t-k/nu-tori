extension SyncChange {
    /// この変更の記録の種類の、サーバーの名前（snake_case）。知らない種類（`.unknown`）は nil
    public var serverKindName: String? {
        recordKind?.rawValue
    }

    /// 全部の case を並べる switch はここ1か所にする。case を足したら、ここに種類を書く。
    /// 種類の適合（`RecordKindWireCoding`）は、自分の case を `if case` で取り出す
    var recordKind: Components.Schemas.RecordKindName? {
        switch self {
        case .weightRecord, .weightRecordDeletion: .weightRecord
        case .accountSettings: .accountSettings
        case .aiUtterance: .aiUtterance
        case .dish, .dishDeletion: .dish
        case .dishEstimationStatus, .dishEstimationStatusDeletion: .dishEstimationStatus
        case .ingredient, .ingredientDeletion: .ingredient
        case .meal, .mealDeletion: .meal
        case .mealEstimationStatus, .mealEstimationStatusDeletion: .mealEstimationStatus
        case .notice, .noticeRemoval: .notice
        case .sentText, .sentTextRemoval: .sentText
        case .sentTextStatus: .sentTextStatus
        case .usualWeighingTime: .usualWeighingTime
        case .weightTrend, .weightTrendAbsence: .weightTrend
        case .unknown: nil
        }
    }
}
