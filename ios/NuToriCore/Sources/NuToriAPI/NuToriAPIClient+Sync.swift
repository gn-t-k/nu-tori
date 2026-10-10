import Foundation
import OpenAPIRuntime

extension NuToriAPIClient {
    /// 1回の要求で送れるのは 500 件まで
    public func pushSyncWrites(
        _ writes: [SyncWrite],
        isFinalBatch: Bool,
        clientState: SyncClientState
    ) async throws -> PushSyncWritesResult {
        let output = try await client.pushSyncWrites(
            body: .json(
                .init(
                    clientState: .init(clientState),
                    writes: writes.compactMap(Components.Schemas.SyncWrite.init),
                    isFinalBatch: isFinalBatch
                )
            )
        )
        switch output {
        case .ok(let ok):
            return .pushed(try ok.body.json.results.map(SyncWriteResult.init))
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public func pullSyncChanges(
        afterSequence: Int,
        clientState: SyncClientState
    ) async throws -> PullSyncChangesResult {
        let output = try await client.pullSyncChanges(
            query: .init(clientState, afterSequence: afterSequence)
        )
        switch output {
        case .ok(let ok):
            return .pulled(SyncChangesPage(try ok.body.json))
        case .badRequest:
            return .badRequest
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    public enum PushSyncWritesResult: Sendable, Equatable {
        /// 送った書き込みと同じ順
        case pushed([SyncWriteResult])
        /// サーバーは何も当てていない
        case badRequest
        case sessionExpired
        case rateLimited
    }

    public enum PullSyncChangesResult: Sendable, Equatable {
        case pulled(SyncChangesPage)
        case badRequest
        case sessionExpired
        case rateLimited
    }

    public struct MalformedResponseError: Error, Equatable {
        public let reason: String
    }
}

extension Components.Schemas.SyncWrite {
    /// サーバーの API にまだ形の無い書き込みは nil にして送らない。結果が返らないので、送り待ちに残る
    fileprivate init?(_ write: SyncWrite) {
        switch write {
        case .createWeightRecord(let writeId, let record):
            self = .createWeightRecord(
                .init(
                    id: writeId.canonicalString,
                    _type: .createWeightRecord,
                    weightRecord: .init(
                        id: record.id.canonicalString,
                        weightKg: record.weightKilograms,
                        measuredAt: record.measuredAt.millisecondsSince1970,
                        timeZone: record.timeZone.identifier,
                        imported: record.imported.map { imported in
                            .init(
                                sourceAppName: imported.sourceAppName,
                                sourceBundleId: imported.sourceBundleId,
                                healthkitSampleUuid: imported.healthKitSampleId.canonicalString,
                                bodyFat: imported.bodyFat.map { bodyFat in
                                    .init(
                                        percentage: bodyFat.percentage,
                                        healthkitSampleUuid: bodyFat.healthKitSampleId
                                            .canonicalString
                                    )
                                }
                            )
                        }
                    )
                )
            )
        case .updateWeightRecord(let writeId, let correction):
            self = .updateWeightRecord(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateWeightRecord,
                    weightRecord: .init(
                        id: correction.id.canonicalString,
                        weightKg: correction.weightKilograms,
                        measuredAt: correction.measuredAt.millisecondsSince1970,
                        timeZone: correction.timeZone.identifier,
                        version: correction.version
                    )
                )
            )
        case .updateAccountSettings(let writeId, let settings):
            self = .updateAccountSettings(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateAccountSettings,
                    accountSettings: .init(
                        id: settings.id.canonicalString,
                        sendsUsageData: settings.sendsUsageData
                    )
                )
            )
        case .sourceDeletedWeightRecord(let writeId, let weightRecordId):
            self = .sourceDeletedWeightRecord(
                .init(
                    id: writeId.canonicalString,
                    _type: .sourceDeletedWeightRecord,
                    weightRecordId: weightRecordId.canonicalString
                )
            )
        case .createMeal(let writeId, let meal):
            self = .createMeal(
                .init(
                    id: writeId.canonicalString,
                    _type: .createMeal,
                    meal: .init(
                        id: meal.id.canonicalString,
                        eatenAt: meal.eatenAt.millisecondsSince1970,
                        eatenAtUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                        sentAt: meal.sentAt.millisecondsSince1970,
                        sentTimeZone: meal.sentTimeZone.identifier,
                        entryMethod: meal.entryMethod.wireName,
                        photos: meal.photoIds.map { .init(id: $0.canonicalString) }
                    )
                )
            )
        case .updateMeal(let writeId, let mealId, let eatenAt):
            self = .updateMeal(
                .init(
                    id: writeId.canonicalString, _type: .updateMeal, mealId: mealId.canonicalString,
                    eatenAt: eatenAt.millisecondsSince1970))
        case .deleteMeal(let writeId, let mealId):
            self = .deleteMeal(
                .init(
                    id: writeId.canonicalString, _type: .deleteMeal, mealId: mealId.canonicalString)
            )
        case .createDish(let writeId, let dish):
            self = .createDish(
                .init(
                    id: writeId.canonicalString,
                    _type: .createDish,
                    dishId: dish.id.canonicalString,
                    mealId: dish.mealId.canonicalString,
                    name: dish.name,
                    positionInMeal: dish.positionInMeal
                )
            )
        case .deleteDish(let writeId, let dishId):
            self = .deleteDish(
                .init(
                    id: writeId.canonicalString, _type: .deleteDish, dishId: dishId.canonicalString)
            )
        case .updateDish(let writeId, let correction):
            self = .updateDish(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateDish,
                    dishId: correction.id.canonicalString,
                    name: correction.name,
                    quantity: correction.quantity.map { quantity in
                        .init(
                            value: quantity.value,
                            proportionedIngredients: quantity.proportionedIngredients.map {
                                .init(
                                    ingredientId: $0.ingredientId.canonicalString,
                                    quantity: $0.quantity)
                            })
                    }
                )
            )
        case .updateIngredient(let writeId, let ingredientId, let quantity):
            self = .updateIngredient(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateIngredient,
                    ingredientId: ingredientId.canonicalString,
                    quantity: quantity
                )
            )
        case .createNotice(let writeId, let notice):
            self = .createNotice(
                .init(
                    id: writeId.canonicalString,
                    _type: .createNotice,
                    notice: .init(
                        id: notice.id.canonicalString,
                        noticeType: notice.noticeType.rawValue,
                        issuedAt: notice.issuedAt.millisecondsSince1970,
                        timeZone: notice.timeZone.identifier,
                        targetOn: notice.targetOn
                    )
                )
            )
        case .respondNotice(let writeId, let noticeId, let response):
            self = .respondNotice(
                .init(
                    id: writeId.canonicalString,
                    _type: .respondNotice,
                    noticeId: noticeId.canonicalString,
                    response: .init(
                        respondedAt: response.respondedAt.millisecondsSince1970,
                        timeZone: response.timeZone.identifier
                    )
                )
            )
        case .createSentText(let writeId, let sentText):
            self = .createSentText(
                .init(
                    id: writeId.canonicalString,
                    _type: .createSentText,
                    sentText: .init(
                        id: sentText.id.canonicalString,
                        body: sentText.body,
                        sentAt: sentText.sentAt.millisecondsSince1970,
                        timeZone: sentText.timeZone.identifier
                    )
                )
            )
        case .resendSentTextAsConversation(let writeId, let sentTextId):
            self = .resendSentTextAsConversation(
                .init(
                    id: writeId.canonicalString,
                    _type: .resendSentTextAsConversation,
                    sentTextId: sentTextId.canonicalString
                )
            )
        // サーバーが受け付ける形（#430）が `server/openapi.json` に入るまで送らない。入ったら生成し直して、ここで作る
        case .resendSentText:
            return nil
        }
    }
}

extension Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload {
    fileprivate init(_ clientState: SyncClientState) {
        self.init(
            deviceId: clientState.deviceId.canonicalString,
            timeZone: clientState.timeZone.identifier,
            appVersion: clientState.appVersion,
            osVersion: clientState.osVersion,
            pendingWriteCount: clientState.pendingWriteCount,
            oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAge.map {
                Int($0.components.seconds)
            },
            pendingPhotoCount: clientState.pendingPhotoCount
        )
    }
}

extension Operations.PullSyncChanges.Input.Query {
    fileprivate init(_ clientState: SyncClientState, afterSequence: Int) {
        self.init(
            deviceId: clientState.deviceId.canonicalString,
            timeZone: clientState.timeZone.identifier,
            appVersion: clientState.appVersion,
            osVersion: clientState.osVersion,
            pendingWriteCount: clientState.pendingWriteCount,
            oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAge.map {
                Int($0.components.seconds)
            },
            pendingPhotoCount: clientState.pendingPhotoCount,
            afterSequence: afterSequence
        )
    }
}

extension SyncWriteResult {
    fileprivate init(_ result: Components.Schemas.SyncWriteResult) throws {
        guard let writeId = UUID(uuidString: result.writeId) else {
            throw NuToriAPIClient.MalformedResponseError(reason: "書き込みの ID が UUID でない")
        }
        switch result.result {
        case "applied":
            self.init(writeId: writeId, outcome: .applied, current: nil)
        case "ignored_duplicate":
            self.init(writeId: writeId, outcome: .ignoredDuplicate, current: nil)
        case "ignored_tombstone":
            self.init(writeId: writeId, outcome: .ignoredTombstone, current: nil)
        case "kept_corrected":
            self.init(writeId: writeId, outcome: .keptCorrected, current: nil)
        case "rejected":
            guard let reason = result.rejectionReason else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けなかった理由が無い")
            }
            self.init(
                writeId: writeId,
                outcome: .rejected(RejectionReason(reason)),
                current: result.current.flatMap(Current.init)
            )
        default:
            self.init(writeId: writeId, outcome: .unknown(result: result.result), current: nil)
        }
    }
}

extension SyncWriteResult.Current {
    /// 知らない状態と、読めない中身は nil にする。サーバーが状態を足しても、古い版のアプリの同期が止まらないように
    fileprivate init?(_ current: Components.Schemas.SyncWriteCurrent) {
        switch current.status {
        case "value":
            guard let change = current.change.map(SyncChange.init) else { return nil }
            self = .value(change)
        case "deleted":
            guard let change = current.change.map(SyncChange.init) else { return nil }
            self = .deleted(change)
        case "absent":
            self = .absent
        default:
            return nil
        }
    }
}

extension SyncWriteResult.RejectionReason {
    fileprivate init(_ reason: String) {
        switch reason {
        case "out_of_range": self = .outOfRange
        case "invalid_time_zone": self = .invalidTimeZone
        case "version_too_low": self = .versionTooLow
        case "record_not_found": self = .recordNotFound
        case "record_before_started_on": self = .recordBeforeStartedOn
        case "invalid_entry_method": self = .invalidEntryMethod
        case "duplicate_photo_ids": self = .duplicatePhotoIds
        case "photo_already_used": self = .photoAlreadyUsed
        case "invalid_notice_type": self = .invalidNoticeType
        case "invalid_target_on": self = .invalidTargetOn
        case "ingredients_replaced": self = .ingredientsReplaced
        case "awaiting_estimation": self = .awaitingEstimation
        case "not_classified_as_meal": self = .notClassifiedAsMeal
        case "reply_not_failed": self = .replyNotFailed
        default: self = .unknown(reason: reason)
        }
    }
}

extension SyncChangesPage {
    fileprivate init(_ body: Operations.PullSyncChanges.Output.Ok.Body.JsonPayload) {
        self.init(
            changes: body.changes.map(SyncChange.init),
            hasMore: body.hasMore,
            nextAfterSequence: body.nextAfterSequence,
            startedOn: body.startedOn
        )
    }
}

extension SyncChange {
    fileprivate init(_ change: Components.Schemas.SyncChange) {
        self.init(kind: change.kind, recordId: change.recordId, record: change.record)
    }

    /// 受け付けなかった書き込みに添えられた今の値も、取りに行く変更と同じ道で読む
    fileprivate init(_ change: Components.Schemas.SyncWriteCurrent.ChangePayload) {
        self.init(kind: change.kind, recordId: change.recordId, record: change.record)
    }

    private init(kind: String, recordId: String, record: some Encodable) {
        switch kind {
        case "weight_record":
            if let record = try? record.decoded(as: WeightRecordPayload.self)
                .syncedWeightRecord
            {
                self = .weightRecord(record)
            } else {
                self = .unknown(kind: kind)
            }
        case "ai_utterance":
            if let utterance = try? record.decoded(as: AiUtterancePayload.self).syncedAiUtterance {
                self = .aiUtterance(utterance)
            } else {
                self = .unknown(kind: kind)
            }
        case "account_settings":
            if let settings = try? record.decoded(as: AccountSettingsPayload.self)
                .syncedAccountSettings
            {
                self = .accountSettings(settings)
            } else {
                self = .unknown(kind: kind)
            }
        case "weight_record_deletion":
            if let recordId = UUID(uuidString: recordId) {
                self = .weightRecordDeletion(recordId: recordId)
            } else {
                self = .unknown(kind: kind)
            }
        case "dish":
            if let dish = try? record.decoded(as: DishPayload.self).syncedDish {
                self = .dish(dish)
            } else {
                self = .unknown(kind: kind)
            }
        case "dish_deletion":
            if let dishId = UUID(uuidString: recordId) {
                self = .dishDeletion(dishId: dishId)
            } else {
                self = .unknown(kind: kind)
            }
        case "dish_estimation_status":
            if let status = try? record.decoded(as: DishEstimationStatusPayload.self)
                .syncedStatus
            {
                self = .dishEstimationStatus(status)
            } else {
                self = .unknown(kind: kind)
            }
        case "dish_estimation_status_deletion":
            if let dishId = UUID(uuidString: recordId) {
                self = .dishEstimationStatusDeletion(dishId: dishId)
            } else {
                self = .unknown(kind: kind)
            }
        case "ingredient":
            if let ingredient = try? record.decoded(as: IngredientPayload.self).syncedIngredient {
                self = .ingredient(ingredient)
            } else {
                self = .unknown(kind: kind)
            }
        case "ingredient_deletion":
            if let ingredientId = UUID(uuidString: recordId) {
                self = .ingredientDeletion(ingredientId: ingredientId)
            } else {
                self = .unknown(kind: kind)
            }
        case "meal":
            if let meal = try? record.decoded(as: MealPayload.self).syncedMeal {
                self = .meal(meal)
            } else {
                self = .unknown(kind: kind)
            }
        case "meal_deletion":
            if let mealId = UUID(uuidString: recordId) {
                self = .mealDeletion(mealId: mealId)
            } else {
                self = .unknown(kind: kind)
            }
        case "meal_estimation_status":
            if let status = try? record.decoded(as: MealEstimationStatusPayload.self)
                .syncedStatus
            {
                self = .mealEstimationStatus(status)
            } else {
                self = .unknown(kind: kind)
            }
        case "meal_estimation_status_deletion":
            if let mealId = UUID(uuidString: recordId) {
                self = .mealEstimationStatusDeletion(mealId: mealId)
            } else {
                self = .unknown(kind: kind)
            }
        case "notice":
            if let notice = try? record.decoded(as: NoticePayload.self).syncedNotice {
                self = .notice(notice)
            } else {
                self = .unknown(kind: kind)
            }
        case "sent_text":
            if let sentText = try? record.decoded(as: SentTextPayload.self).syncedSentText {
                self = .sentText(sentText)
            } else {
                self = .unknown(kind: kind)
            }
        case "sent_text_status":
            if let status = try? record.decoded(as: SentTextStatusPayload.self).syncedStatus {
                self = .sentTextStatus(status)
            } else {
                self = .unknown(kind: kind)
            }
        case "usual_weighing_time":
            if let id = UUID(uuidString: recordId),
                let payload = try? record.decoded(as: UsualWeighingTimePayload.self)
            {
                self = .usualWeighingTime(
                    SyncedUsualWeighingTime(id: id, minuteOfDay: payload.minuteOfDay))
            } else {
                self = .unknown(kind: kind)
            }
        case "weight_trend":
            if let trend = try? record.decoded(as: WeightTrendPayload.self).syncedWeightTrend {
                self = .weightTrend(trend)
            } else {
                self = .unknown(kind: kind)
            }
        case "weight_trend_absence":
            self = .weightTrendAbsence
        default:
            self = .unknown(kind: kind)
        }
    }
}

extension Encodable {
    func decoded<Payload: Decodable>(as payload: Payload.Type) throws -> Payload {
        try JSONDecoder().decode(payload, from: JSONEncoder().encode(self))
    }
}

extension Date {
    var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }
}
