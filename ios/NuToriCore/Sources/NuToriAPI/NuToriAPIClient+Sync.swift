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
                    writes: writes.map(Components.Schemas.SyncWrite.init),
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
    fileprivate init(_ write: SyncWrite) {
        switch write {
        case .createWeightRecord(let writeId, let record):
            self = .createWeightRecord(
                .init(
                    id: writeId.uuidString,
                    _type: .createWeightRecord,
                    weightRecord: .init(
                        id: record.id.uuidString,
                        weightKg: record.weightKilograms,
                        measuredAt: record.measuredAt.millisecondsSince1970,
                        timeZone: record.timeZone.identifier,
                        imported: record.imported.map { imported in
                            .init(
                                sourceAppName: imported.sourceAppName,
                                sourceBundleId: imported.sourceBundleId,
                                healthkitSampleUuid: imported.healthKitSampleId.uuidString,
                                bodyFat: imported.bodyFat.map { bodyFat in
                                    .init(
                                        percentage: bodyFat.percentage,
                                        healthkitSampleUuid: bodyFat.healthKitSampleId.uuidString
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
                    id: writeId.uuidString,
                    _type: .updateWeightRecord,
                    weightRecord: .init(
                        id: correction.id.uuidString,
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
                    id: writeId.uuidString,
                    _type: .updateAccountSettings,
                    accountSettings: .init(
                        id: settings.id.uuidString,
                        sendsUsageData: settings.sendsUsageData
                    )
                )
            )
        case .sourceDeletedWeightRecord(let writeId, let weightRecordId):
            self = .sourceDeletedWeightRecord(
                .init(
                    id: writeId.uuidString,
                    _type: .sourceDeletedWeightRecord,
                    weightRecordId: weightRecordId.uuidString
                )
            )
        case .createMeal(let writeId, let meal):
            self = .createMeal(
                .init(
                    id: writeId.uuidString,
                    _type: .createMeal,
                    meal: .init(
                        id: meal.id.uuidString,
                        eatenAt: meal.eatenAt.millisecondsSince1970,
                        eatenAtUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                        sentAt: meal.sentAt.millisecondsSince1970,
                        sentTimeZone: meal.sentTimeZone.identifier,
                        entryMethod: meal.entryMethod.rawValue,
                        photos: meal.photoIds.map { .init(id: $0.uuidString) }
                    )
                )
            )
        case .deleteMeal(let writeId, let mealId):
            self = .deleteMeal(
                .init(id: writeId.uuidString, _type: .deleteMeal, mealId: mealId.uuidString))
        }
    }
}

extension Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload {
    fileprivate init(_ clientState: SyncClientState) {
        self.init(
            deviceId: clientState.deviceId.uuidString,
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
            deviceId: clientState.deviceId.uuidString,
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
        default:
            self = .unknown(kind: kind)
        }
    }

    fileprivate struct WeightRecordPayload: Decodable {
        let id: String
        let weightKg: Double
        let measuredAt: Int
        let timeZone: String
        let version: Int
        let imported: Imported?

        struct Imported: Decodable {
            let sourceAppName: String
            let sourceBundleId: String
            let healthkitSampleUuid: String
            let bodyFat: BodyFat?

            struct BodyFat: Decodable {
                let percentage: Double
                let healthkitSampleUuid: String
            }
        }

        var syncedWeightRecord: SyncedWeightRecord? {
            guard let id = UUID(uuidString: id), let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            var importedSource: SyncedWeightRecord.Imported?
            if let imported {
                guard let sampleId = UUID(uuidString: imported.healthkitSampleUuid) else {
                    return nil
                }
                var bodyFat: SyncedWeightRecord.Imported.BodyFat?
                if let payload = imported.bodyFat {
                    guard let bodyFatSampleId = UUID(uuidString: payload.healthkitSampleUuid) else {
                        return nil
                    }
                    bodyFat = .init(
                        percentage: payload.percentage, healthKitSampleId: bodyFatSampleId)
                }
                importedSource = .init(
                    sourceAppName: imported.sourceAppName,
                    sourceBundleId: imported.sourceBundleId,
                    healthKitSampleId: sampleId,
                    bodyFat: bodyFat
                )
            }
            return SyncedWeightRecord(
                id: id,
                weightKilograms: weightKg,
                measuredAt: Date(timeIntervalSince1970: Double(measuredAt) / 1000),
                timeZone: timeZone,
                version: version,
                imported: importedSource
            )
        }
    }
}

extension SyncChange {
    fileprivate struct AccountSettingsPayload: Decodable {
        let id: String
        let sendsUsageData: Bool

        var syncedAccountSettings: SyncedAccountSettings? {
            UUID(uuidString: id).map {
                SyncedAccountSettings(id: $0, sendsUsageData: sendsUsageData)
            }
        }
    }
}

extension SyncChange {
    /// 知らない入口と、読めない ID・タイムゾーンは nil にする
    fileprivate struct MealPayload: Decodable {
        let id: String
        let eatenAt: Int
        let eatenAtUtcOffsetSeconds: Int
        let sentAt: Int
        let sentTimeZone: String
        let entryMethod: String
        let photos: [Photo]

        struct Photo: Decodable {
            let id: String
        }

        var syncedMeal: SyncedMeal? {
            guard let id = UUID(uuidString: id),
                let sentTimeZone = TimeZone(identifier: sentTimeZone),
                let entryMethod = SyncedMeal.EntryMethod(rawValue: entryMethod)
            else {
                return nil
            }
            let photoIds = photos.compactMap { UUID(uuidString: $0.id) }
            guard photoIds.count == photos.count else { return nil }
            return SyncedMeal(
                id: id,
                eatenAt: Date(timeIntervalSince1970: Double(eatenAt) / 1000),
                eatenUtcOffsetSeconds: eatenAtUtcOffsetSeconds,
                sentAt: Date(timeIntervalSince1970: Double(sentAt) / 1000),
                sentTimeZone: sentTimeZone,
                entryMethod: entryMethod,
                photoIds: photoIds
            )
        }
    }

    /// 知らない状態は nil にする。サーバーが状態を足しても、古い版のアプリは前の状態のまま同期を続ける
    fileprivate struct MealEstimationStatusPayload: Decodable {
        let mealId: String
        let status: String

        var syncedStatus: SyncedMealEstimationStatus? {
            guard let mealId = UUID(uuidString: mealId),
                let status = SyncedMealEstimationStatus.Status(rawValue: status)
            else {
                return nil
            }
            return SyncedMealEstimationStatus(mealId: mealId, status: status)
        }
    }
}

extension SyncChange {
    fileprivate struct DishPayload: Decodable {
        let id: String
        let mealId: String
        let name: String
        let quantity: Double
        let unit: String
        let positionInMeal: Int
        let version: Int

        var syncedDish: SyncedDish? {
            guard let id = UUID(uuidString: id), let mealId = UUID(uuidString: mealId) else {
                return nil
            }
            return SyncedDish(
                id: id, mealId: mealId, name: name, quantity: quantity, unit: unit,
                positionInMeal: positionInMeal, version: version)
        }
    }

    /// 知らない出どころと、読めない ID は nil にする。知らない栄養の項目の名前は、そのまま持つ
    fileprivate struct IngredientPayload: Decodable {
        let id: String
        let dishId: String
        let name: String
        let quantity: Double
        let unit: String
        let edibleGramsPerUnit: Double
        let positionInDish: Int
        let nutrientSource: NutrientSourcePayload
        let nutrients: [String: Double]

        struct NutrientSourcePayload: Decodable {
            let type: String
            let labelBasisGrams: Double?
            let foodNumber: String?

            var syncedSource: SyncedIngredient.NutrientSource? {
                switch type {
                case "nutrition_label":
                    labelBasisGrams.map { .nutritionLabel(basisGrams: $0) }
                case "food_composition":
                    foodNumber.map { .foodComposition(foodNumber: $0) }
                case "estimated":
                    .estimated
                default:
                    nil
                }
            }
        }

        var syncedIngredient: SyncedIngredient? {
            guard let id = UUID(uuidString: id), let dishId = UUID(uuidString: dishId),
                let source = nutrientSource.syncedSource
            else {
                return nil
            }
            return SyncedIngredient(
                id: id, dishId: dishId, name: name, quantity: quantity, unit: unit,
                edibleGramsPerUnit: edibleGramsPerUnit, positionInDish: positionInDish,
                nutrientSource: source, nutrients: nutrients)
        }
    }
}

extension Encodable {
    fileprivate func decoded<Payload: Decodable>(as payload: Payload.Type) throws -> Payload {
        try JSONDecoder().decode(payload, from: JSONEncoder().encode(self))
    }
}

extension Date {
    fileprivate var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }
}
