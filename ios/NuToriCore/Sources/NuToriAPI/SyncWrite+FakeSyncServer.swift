#if DEBUG
    extension SyncWrite {
        /// 書き込みが当たる記録
        var recordKey: FakeSyncServer.RecordKey {
            switch self {
            case .createWeightRecord(_, let record): .init(kind: .weightRecord, id: record.id)
            case .updateWeightRecord(_, let correction):
                .init(kind: .weightRecord, id: correction.id)
            case .sourceDeletedWeightRecord(_, let weightRecordId):
                .init(kind: .weightRecord, id: weightRecordId)
            case .updateAccountSettings(_, let settings):
                .init(kind: .accountSettings, id: settings.id)
            case .createMeal(_, let meal): .init(kind: .meal, id: meal.id)
            case .updateMeal(_, let mealId, _): .init(kind: .meal, id: mealId)
            case .deleteMeal(_, let mealId): .init(kind: .meal, id: mealId)
            case .createDish(_, let dish): .init(kind: .dish, id: dish.id)
            case .deleteDish(_, let dishId): .init(kind: .dish, id: dishId)
            case .updateDish(_, let correction): .init(kind: .dish, id: correction.id)
            case .updateIngredient(_, let ingredientId, _):
                .init(kind: .ingredient, id: ingredientId)
            case .createNotice(_, let notice): .init(kind: .notice, id: notice.id)
            case .respondNotice(_, let noticeId, _): .init(kind: .notice, id: noticeId)
            }
        }
    }

#endif
