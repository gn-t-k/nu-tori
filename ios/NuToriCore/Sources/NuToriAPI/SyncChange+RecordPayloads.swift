import Foundation

/// 取りに行く変更の record の形。端末が読むほかに、Debug のビルドでは偽の同期サーバー（`FakeSyncServer`）が書く
extension SyncChange {
    struct WeightRecordPayload: Decodable {
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
    struct AccountSettingsPayload: Decodable {
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
    struct MealPayload: Decodable {
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
    struct MealEstimationStatusPayload: Decodable {
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
    /// 知らない状態は nil にする。サーバーが状態を足しても、古い版のアプリは前の状態のまま同期を続ける
    struct DishEstimationStatusPayload: Decodable {
        let dishId: String
        let status: String

        var syncedStatus: SyncedDishEstimationStatus? {
            guard let dishId = UUID(uuidString: dishId),
                let status = SyncedDishEstimationStatus.Status(rawValue: status)
            else {
                return nil
            }
            return SyncedDishEstimationStatus(dishId: dishId, status: status)
        }
    }

    struct DishPayload: Decodable {
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
    struct IngredientPayload: Decodable {
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

extension SyncChange {
    /// 知らない種類と、読めない ID・タイムゾーンは nil にする
    struct NoticePayload: Decodable {
        let id: String
        let noticeType: String
        let issuedAt: Int
        let timeZone: String
        let targetOn: String
        let response: Response?

        struct Response: Decodable {
            let respondedAt: Int
            let timeZone: String
        }

        var syncedNotice: SyncedNotice? {
            guard let id = UUID(uuidString: id),
                let noticeType = SyncedNotice.NoticeType(rawValue: noticeType),
                let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            var syncedResponse: SyncedNotice.Response?
            if let response {
                guard let responseTimeZone = TimeZone(identifier: response.timeZone) else {
                    return nil
                }
                syncedResponse = SyncedNotice.Response(
                    respondedAt: Date(timeIntervalSince1970: Double(response.respondedAt) / 1000),
                    timeZone: responseTimeZone)
            }
            return SyncedNotice(
                id: id,
                noticeType: noticeType,
                issuedAt: Date(timeIntervalSince1970: Double(issuedAt) / 1000),
                timeZone: timeZone,
                targetOn: targetOn,
                response: syncedResponse
            )
        }
    }

    struct UsualWeighingTimePayload: Decodable {
        let minuteOfDay: Int
    }

    struct WeightTrendPayload: Decodable {
        let days: [Day]

        struct Day: Decodable {
            let calendarDay: String
            let trendKg: Double
        }

        var syncedWeightTrend: SyncedWeightTrend {
            SyncedWeightTrend(
                days: days.map {
                    SyncedWeightTrend.Day(calendarDay: $0.calendarDay, trendKilograms: $0.trendKg)
                })
        }
    }
}

#if DEBUG
    extension SyncChange.WeightRecordPayload: Encodable {}
    extension SyncChange.WeightRecordPayload.Imported: Encodable {}
    extension SyncChange.WeightRecordPayload.Imported.BodyFat: Encodable {}
    extension SyncChange.AccountSettingsPayload: Encodable {}
    extension SyncChange.MealPayload: Encodable {}
    extension SyncChange.MealPayload.Photo: Encodable {}
    extension SyncChange.MealEstimationStatusPayload: Encodable {}
    extension SyncChange.DishPayload: Encodable {}
    extension SyncChange.DishEstimationStatusPayload: Encodable {}
    extension SyncChange.IngredientPayload: Encodable {}
    extension SyncChange.IngredientPayload.NutrientSourcePayload: Encodable {}
    extension SyncChange.NoticePayload: Encodable {}
    extension SyncChange.NoticePayload.Response: Encodable {}
    extension SyncChange.UsualWeighingTimePayload: Encodable {}
    extension SyncChange.WeightTrendPayload: Encodable {}
    extension SyncChange.WeightTrendPayload.Day: Encodable {}
#endif
