#if DEBUG
    import Foundation

    /// 偽の同期サーバーが、記録を置く鍵と、返す変更の線上の形を決める
    extension SyncChange {
        var recordKey: FakeSyncServer.RecordKey {
            switch self {
            case .weightRecord(let record): .init(kind: .weightRecord, id: record.id)
            case .weightRecordDeletion(let recordId): .init(kind: .weightRecord, id: recordId)
            case .accountSettings(let settings): .init(kind: .accountSettings, id: settings.id)
            case .dish(let dish): .init(kind: .dish, id: dish.id)
            case .dishDeletion(let dishId): .init(kind: .dish, id: dishId)
            case .dishEstimationStatus(let status):
                .init(kind: .dishEstimationStatus, id: status.dishId)
            case .dishEstimationStatusDeletion(let dishId):
                .init(kind: .dishEstimationStatus, id: dishId)
            case .ingredient(let ingredient): .init(kind: .ingredient, id: ingredient.id)
            case .ingredientDeletion(let ingredientId): .init(kind: .ingredient, id: ingredientId)
            case .meal(let meal): .init(kind: .meal, id: meal.id)
            case .mealDeletion(let mealId): .init(kind: .meal, id: mealId)
            case .mealEstimationStatus(let status):
                .init(kind: .mealEstimationStatus, id: status.mealId)
            case .mealEstimationStatusDeletion(let mealId):
                .init(kind: .mealEstimationStatus, id: mealId)
            case .notice(let notice): .init(kind: .notice, id: notice.id)
            case .noticeRemoval(let noticeId): .init(kind: .notice, id: noticeId)
            case .usualWeighingTime(let time): .init(kind: .usualWeighingTime, id: time.id)
            // 傾向はアカウントに1つで、recordId は種類の名前
            case .weightTrend, .weightTrendAbsence:
                .init(
                    kind: .weightTrend, id: Components.Schemas.RecordKindName.weightTrend.rawValue)
            case .unknown(let kind):
                preconditionFailure("知らない種類 \(kind) の記録は置けない")
            }
        }

        var isDeletion: Bool {
            switch self {
            case .weightRecordDeletion, .dishDeletion, .dishEstimationStatusDeletion,
                .ingredientDeletion, .mealDeletion, .mealEstimationStatusDeletion, .noticeRemoval,
                .weightTrendAbsence:
                true
            case .weightRecord, .accountSettings, .dish, .dishEstimationStatus, .ingredient, .meal,
                .mealEstimationStatus, .notice, .usualWeighingTime, .weightTrend, .unknown:
                false
            }
        }

        /// 線上の kind。記録の種類の名前に、削除の印は `_deletion`、傾向が無いことは `_absence` を付ける
        fileprivate var wireKind: String {
            let name = recordKey.kind.rawValue
            switch self {
            case .weightRecord, .accountSettings, .dish, .dishEstimationStatus, .ingredient, .meal,
                .mealEstimationStatus, .notice, .usualWeighingTime, .weightTrend, .unknown:
                return name
            case .weightRecordDeletion, .dishDeletion, .dishEstimationStatusDeletion,
                .ingredientDeletion, .mealDeletion, .mealEstimationStatusDeletion:
                return "\(name)_deletion"
            case .weightTrendAbsence:
                return "\(name)_absence"
            case .noticeRemoval:
                preconditionFailure("サーバーは知らせの取り除きを返さない")
            }
        }

        /// 生成した型の record（中身を決めない入れ物）に、記録の中身の形を詰める。削除の印は空の record
        fileprivate func recordPayload<Payload: Decodable>() throws -> Payload {
            let payload: any Encodable =
                switch self {
                case .weightRecord(let record): WeightRecordPayload(record)
                case .accountSettings(let settings):
                    AccountSettingsPayload(
                        id: settings.id.uuidString, sendsUsageData: settings.sendsUsageData)
                case .dish(let dish): DishPayload(dish)
                case .dishEstimationStatus(let status):
                    DishEstimationStatusPayload(
                        dishId: status.dishId.uuidString, status: status.status.rawValue)
                case .ingredient(let ingredient): IngredientPayload(ingredient)
                case .meal(let meal): MealPayload(meal)
                case .mealEstimationStatus(let status):
                    MealEstimationStatusPayload(
                        mealId: status.mealId.uuidString, status: status.status.rawValue)
                case .notice(let notice): NoticePayload(notice)
                case .usualWeighingTime(let time):
                    UsualWeighingTimePayload(minuteOfDay: time.minuteOfDay)
                case .weightTrend(let trend):
                    WeightTrendPayload(
                        days: trend.days.map {
                            .init(calendarDay: $0.calendarDay, trendKg: $0.trendKilograms)
                        })
                case .weightRecordDeletion, .dishDeletion, .dishEstimationStatusDeletion,
                    .ingredientDeletion, .mealDeletion, .mealEstimationStatusDeletion,
                    .noticeRemoval, .weightTrendAbsence, .unknown:
                    [String: String]()
                }
            return try payload.decoded(as: Payload.self)
        }
    }

    extension FakeSyncServer.RecordKey {
        init(kind: Components.Schemas.RecordKindName, id: UUID) {
            self.init(kind: kind, id: id.uuidString)
        }
    }

    extension Components.Schemas.SyncChange {
        init(_ change: SyncChange, sequence: Int) throws {
            self.init(
                sequence: sequence, kind: change.wireKind, recordId: change.recordKey.id,
                record: try change.recordPayload())
        }
    }

    extension Components.Schemas.SyncWriteCurrent.ChangePayload {
        init(_ change: SyncChange) throws {
            self.init(
                kind: change.wireKind, recordId: change.recordKey.id,
                record: try change.recordPayload())
        }
    }

    extension SyncWriteResult.Current {
        /// 断った書き込みに添える `current` の JSON。テストのトランスポートが、偽の同期サーバーと同じ形で返すため
        public func json() throws -> String {
            String(
                decoding: try JSONEncoder().encode(Components.Schemas.SyncWriteCurrent(self)),
                as: UTF8.self)
        }
    }

    extension Components.Schemas.SyncWriteCurrent {
        init(_ current: SyncWriteResult.Current) throws {
            switch current {
            case .value(let change):
                self.init(status: "value", change: try .init(change))
            case .deleted(let change):
                self.init(status: "deleted", change: try .init(change))
            case .absent:
                self.init(status: "absent")
            }
        }
    }

    extension SyncChange.WeightRecordPayload {
        fileprivate init(_ record: SyncedWeightRecord) {
            self.init(
                id: record.id.uuidString,
                weightKg: record.weightKilograms,
                measuredAt: record.measuredAt.millisecondsSince1970,
                timeZone: record.timeZone.identifier,
                version: record.version,
                imported: record.imported.map { imported in
                    Imported(
                        sourceAppName: imported.sourceAppName,
                        sourceBundleId: imported.sourceBundleId,
                        healthkitSampleUuid: imported.healthKitSampleId.uuidString,
                        bodyFat: imported.bodyFat.map {
                            .init(
                                percentage: $0.percentage,
                                healthkitSampleUuid: $0.healthKitSampleId.uuidString)
                        }
                    )
                }
            )
        }
    }

    extension SyncChange.MealPayload {
        fileprivate init(_ meal: SyncedMeal) {
            self.init(
                id: meal.id.uuidString,
                eatenAt: meal.eatenAt.millisecondsSince1970,
                eatenAtUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                sentAt: meal.sentAt.millisecondsSince1970,
                sentTimeZone: meal.sentTimeZone.identifier,
                entryMethod: meal.entryMethod.rawValue,
                photos: meal.photoIds.map { .init(id: $0.uuidString) }
            )
        }
    }

    extension SyncChange.DishPayload {
        fileprivate init(_ dish: SyncedDish) {
            self.init(
                id: dish.id.uuidString, mealId: dish.mealId.uuidString, name: dish.name,
                quantity: dish.quantity?.value, unit: dish.quantity?.unit,
                quantitySource: dish.quantity?.source.rawValue,
                positionInMeal: dish.positionInMeal, version: dish.version)
        }
    }

    extension SyncChange.IngredientPayload {
        fileprivate init(_ ingredient: SyncedIngredient) {
            let source: NutrientSourcePayload =
                switch ingredient.nutrientSource {
                case .nutritionLabel(let basisGrams):
                    .init(type: "nutrition_label", labelBasisGrams: basisGrams, foodNumber: nil)
                case .foodComposition(let foodNumber):
                    .init(type: "food_composition", labelBasisGrams: nil, foodNumber: foodNumber)
                case .estimated:
                    .init(type: "estimated", labelBasisGrams: nil, foodNumber: nil)
                }
            self.init(
                id: ingredient.id.uuidString, dishId: ingredient.dishId.uuidString,
                name: ingredient.name, quantity: ingredient.quantity,
                quantitySource: ingredient.quantitySource.rawValue, unit: ingredient.unit,
                edibleGramsPerUnit: ingredient.edibleGramsPerUnit,
                positionInDish: ingredient.positionInDish, nutrientSource: source,
                nutrients: ingredient.nutrients)
        }
    }

    extension SyncChange.NoticePayload {
        fileprivate init(_ notice: SyncedNotice) {
            self.init(
                id: notice.id.uuidString,
                noticeType: notice.noticeType.rawValue,
                issuedAt: notice.issuedAt.millisecondsSince1970,
                timeZone: notice.timeZone.identifier,
                targetOn: notice.targetOn,
                response: notice.response.map {
                    .init(
                        respondedAt: $0.respondedAt.millisecondsSince1970,
                        timeZone: $0.timeZone.identifier)
                }
            )
        }
    }
#endif
