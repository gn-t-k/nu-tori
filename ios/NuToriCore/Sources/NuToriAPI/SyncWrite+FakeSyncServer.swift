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
            case .deleteMeal(_, let mealId): .init(kind: .meal, id: mealId)
            case .createNotice(_, let notice): .init(kind: .notice, id: notice.id)
            case .respondNotice(_, let noticeId, _): .init(kind: .notice, id: noticeId)
            }
        }
    }

#endif
