#if DEBUG
    public import Foundation

    /// `POST /v1/sync/writes` で端末が送った本文を、送る前の型に戻したもの。偽の同期サーバーとテストが読む
    ///
    /// 生成した型で読むので、線上の名前をここに書かない。知らない種類の書き込みや、形の合わない値を読んだら投げる
    public struct SentSyncWrites: Sendable, Equatable {
        public let clientState: SyncClientState
        public let isFinalBatch: Bool
        public let writes: [SyncWrite]

        public init(json: Data) throws {
            let payload = try JSONDecoder().decode(
                Operations.PushSyncWrites.Input.Body.JsonPayload.self, from: json)
            clientState = try SyncClientState(payload.clientState)
            isFinalBatch = payload.isFinalBatch
            writes = try payload.writes.map(SyncWrite.init)
        }

        public struct MalformedBodyError: Error {
            public let reason: String
        }
    }

    extension SyncClientState {
        fileprivate init(
            _ state: Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload
        ) throws {
            self.init(
                deviceId: try uuid(state.deviceId),
                timeZone: try knownTimeZone(state.timeZone),
                appVersion: state.appVersion,
                osVersion: state.osVersion,
                pendingWriteCount: state.pendingWriteCount,
                oldestPendingWriteAge: state.oldestPendingWriteAgeSeconds.map { .seconds($0) },
                pendingPhotoCount: state.pendingPhotoCount
            )
        }
    }

    extension SyncWrite {
        public var writeId: UUID {
            switch self {
            case .createWeightRecord(let writeId, _), .updateWeightRecord(let writeId, _),
                .sourceDeletedWeightRecord(let writeId, _), .updateAccountSettings(let writeId, _),
                .createMeal(let writeId, _), .deleteMeal(let writeId, _),
                .createNotice(let writeId, _), .respondNotice(let writeId, _, _):
                writeId
            }
        }

        fileprivate init(_ write: Components.Schemas.SyncWrite) throws {
            switch write {
            case .createWeightRecord(let write):
                let record = write.weightRecord
                self = .createWeightRecord(
                    writeId: try uuid(write.id),
                    record: NewWeightRecord(
                        id: try uuid(record.id),
                        weightKilograms: record.weightKg,
                        measuredAt: date(record.measuredAt),
                        timeZone: try knownTimeZone(record.timeZone),
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
                        timeZone: try knownTimeZone(record.timeZone),
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
                    throw SentSyncWrites.MalformedBodyError(reason: "知らない入口 \(meal.entryMethod)")
                }
                self = .createMeal(
                    writeId: try uuid(write.id),
                    meal: SyncedMeal(
                        id: try uuid(meal.id),
                        eatenAt: date(meal.eatenAt),
                        eatenUtcOffsetSeconds: meal.eatenAtUtcOffsetSeconds,
                        sentAt: date(meal.sentAt),
                        sentTimeZone: try knownTimeZone(meal.sentTimeZone),
                        entryMethod: entryMethod,
                        photoIds: try meal.photos.map { try uuid($0.id) }
                    ))
            case .deleteMeal(let write):
                self = .deleteMeal(writeId: try uuid(write.id), mealId: try uuid(write.mealId))
            case .createNotice(let write):
                let notice = write.notice
                guard let noticeType = SyncedNotice.NoticeType(rawValue: notice.noticeType) else {
                    throw SentSyncWrites.MalformedBodyError(
                        reason: "知らない知らせの種類 \(notice.noticeType)")
                }
                self = .createNotice(
                    writeId: try uuid(write.id),
                    notice: NewNotice(
                        id: try uuid(notice.id),
                        noticeType: noticeType,
                        issuedAt: date(notice.issuedAt),
                        timeZone: try knownTimeZone(notice.timeZone),
                        targetOn: notice.targetOn
                    ))
            case .respondNotice(let write):
                self = .respondNotice(
                    writeId: try uuid(write.id),
                    noticeId: try uuid(write.noticeId),
                    response: SyncedNotice.Response(
                        respondedAt: date(write.response.respondedAt),
                        timeZone: try knownTimeZone(write.response.timeZone)))
            }
        }
    }

    private func uuid(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw SentSyncWrites.MalformedBodyError(reason: "UUID でない \(value)")
        }
        return uuid
    }

    private func knownTimeZone(_ identifier: String) throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw SentSyncWrites.MalformedBodyError(reason: "知らないタイムゾーン \(identifier)")
        }
        return timeZone
    }

    private func date(_ milliseconds: Int) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
#endif
