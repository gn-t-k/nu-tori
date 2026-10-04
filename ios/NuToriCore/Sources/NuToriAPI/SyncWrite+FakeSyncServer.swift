#if DEBUG
    import Foundation

    /// 偽の同期サーバーが、生成した型で読んだ書き込みを、端末が送る形に戻す
    extension SyncWrite {
        init(_ write: Components.Schemas.SyncWrite) throws {
            switch write {
            case .createWeightRecord(let write):
                let record = write.weightRecord
                self = .createWeightRecord(
                    writeId: try uuid(write.id),
                    record: NewWeightRecord(
                        id: try uuid(record.id),
                        weightKilograms: record.weightKg,
                        measuredAt: date(record.measuredAt),
                        timeZone: try timeZone(record.timeZone),
                        imported: try record.imported.map { imported in
                            SyncedWeightRecord.Imported(
                                sourceAppName: imported.sourceAppName,
                                sourceBundleId: imported.sourceBundleId,
                                healthKitSampleId: try uuid(imported.healthkitSampleUuid),
                                bodyFat: try imported.bodyFat.map { bodyFat in
                                    .init(
                                        percentage: bodyFat.percentage,
                                        healthKitSampleId: try uuid(bodyFat.healthkitSampleUuid))
                                }
                            )
                        }
                    ))
            case .updateWeightRecord(let write):
                let record = write.weightRecord
                self = .updateWeightRecord(
                    writeId: try uuid(write.id),
                    correction: WeightRecordCorrection(
                        id: try uuid(record.id),
                        weightKilograms: record.weightKg,
                        measuredAt: date(record.measuredAt),
                        timeZone: try timeZone(record.timeZone),
                        version: record.version
                    ))
            case .sourceDeletedWeightRecord(let write):
                self = .sourceDeletedWeightRecord(
                    writeId: try uuid(write.id), weightRecordId: try uuid(write.weightRecordId))
            case .updateAccountSettings(let write):
                self = .updateAccountSettings(
                    writeId: try uuid(write.id),
                    settings: SyncedAccountSettings(
                        id: try uuid(write.accountSettings.id),
                        sendsUsageData: write.accountSettings.sendsUsageData))
            case .createMeal(let write):
                let meal = write.meal
                guard let entryMethod = SyncedMeal.EntryMethod(rawValue: meal.entryMethod) else {
                    throw FakeSyncServer.MalformedRequestError(reason: "知らない入口 \(meal.entryMethod)")
                }
                self = .createMeal(
                    writeId: try uuid(write.id),
                    meal: SyncedMeal(
                        id: try uuid(meal.id),
                        eatenAt: date(meal.eatenAt),
                        eatenUtcOffsetSeconds: meal.eatenAtUtcOffsetSeconds,
                        sentAt: date(meal.sentAt),
                        sentTimeZone: try timeZone(meal.sentTimeZone),
                        entryMethod: entryMethod,
                        photoIds: try meal.photos.map { try uuid($0.id) }
                    ))
            case .deleteMeal(let write):
                self = .deleteMeal(writeId: try uuid(write.id), mealId: try uuid(write.mealId))
            case .createNotice(let write):
                let notice = write.notice
                guard let noticeType = SyncedNotice.NoticeType(rawValue: notice.noticeType) else {
                    throw FakeSyncServer.MalformedRequestError(
                        reason: "知らない知らせの種類 \(notice.noticeType)")
                }
                self = .createNotice(
                    writeId: try uuid(write.id),
                    notice: NewNotice(
                        id: try uuid(notice.id),
                        noticeType: noticeType,
                        issuedAt: date(notice.issuedAt),
                        timeZone: try timeZone(notice.timeZone),
                        targetOn: notice.targetOn
                    ))
            case .respondNotice(let write):
                self = .respondNotice(
                    writeId: try uuid(write.id),
                    noticeId: try uuid(write.noticeId),
                    response: SyncedNotice.Response(
                        respondedAt: date(write.response.respondedAt),
                        timeZone: try timeZone(write.response.timeZone)))
            }
        }

        var writeId: UUID {
            switch self {
            case .createWeightRecord(let writeId, _), .updateWeightRecord(let writeId, _),
                .sourceDeletedWeightRecord(let writeId, _), .updateAccountSettings(let writeId, _),
                .createMeal(let writeId, _), .deleteMeal(let writeId, _),
                .createNotice(let writeId, _), .respondNotice(let writeId, _, _):
                writeId
            }
        }

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

    private func uuid(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw FakeSyncServer.MalformedRequestError(reason: "UUID でない \(value)")
        }
        return uuid
    }

    private func timeZone(_ identifier: String) throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw FakeSyncServer.MalformedRequestError(reason: "知らないタイムゾーン \(identifier)")
        }
        return timeZone
    }

    private func date(_ milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
#endif
