import Foundation
import HealthKit
import NuToriCore
import os

nonisolated final class HealthKitHealthStore: HealthStore, @unchecked Sendable {
    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .notYetRequested }
        switch try await store.statusForAuthorizationRequest(toShare: shareTypes, read: readTypes) {
        case .shouldRequest, .unknown:
            return .notYetRequested
        case .unnecessary:
            return .alreadyRequested
        @unknown default:
            return .notYetRequested
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func isWeightWriteAuthorized() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return store.authorizationStatus(for: Self.bodyMass) == .sharingAuthorized
    }

    func earliestAuthorizedSampleDate() async throws -> Date? {
        guard #available(iOS 27, *) else { return nil }
        return try await authorizedBoundaries().bodyMass
    }

    func readWeightChanges(after anchor: HealthAnchor?, notBefore: Date?) async throws
        -> HealthChanges
    {
        let stored = StoredQueryAnchors(anchor)
        let boundaries = try await authorizedBoundaries()
        let weights = try await readQuantity(
            Self.bodyMass,
            anchor: stored.bodyMassAnchor,
            notBefore: laterDate(notBefore, boundaries.bodyMass)
        )
        let bodyFats = try await readQuantity(
            Self.bodyFatPercentage,
            anchor: stored.bodyFatAnchor,
            notBefore: laterDate(notBefore, boundaries.bodyFat)
        )
        let next = StoredQueryAnchors(bodyMass: weights.anchor, bodyFat: bodyFats.anchor)
        return HealthChanges(
            weights: weights.samples.map(weightSample),
            bodyFats: bodyFats.samples.map(bodyFatSample),
            deletions: weights.deletions.map { .weight(sampleId: $0.uuid) }
                + bodyFats.deletions.map { .bodyFat(sampleId: $0.uuid) },
            anchor: HealthAnchor(data: next.encoded())
        )
    }

    func writeWeight(_ write: HealthWeightWrite) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let sample = HKQuantitySample(
            type: Self.bodyMass,
            quantity: HKQuantity(unit: Self.kilogram, doubleValue: write.kilograms),
            start: write.instant,
            end: write.instant,
            metadata: [
                HKMetadataKeySyncIdentifier: write.syncId.uuidString,
                HKMetadataKeySyncVersion: NSNumber(value: write.syncVersion),
                HKMetadataKeyTimeZone: write.timeZone.identifier,
            ]
        )
        try await store.save(sample)
    }

    func nutritionAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .alreadyRequested }
        switch try await store.statusForAuthorizationRequest(
            toShare: nutritionShareTypes, read: [])
        {
        case .shouldRequest, .unknown:
            return .notYetRequested
        case .unnecessary:
            return .alreadyRequested
        @unknown default:
            return .notYetRequested
        }
    }

    func requestNutritionAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: nutritionShareTypes, read: [])
    }

    func writeAuthorizedNutrients() async throws -> Set<HealthNutrient> {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        return Set(
            HealthNutrient.allCases.filter {
                store.authorizationStatus(for: Self.quantityType(for: $0)) == .sharingAuthorized
            })
    }

    /// 食品の組（食品名は `HKMetadataKeyFoodType`）で書く。組は、中の種類の書き込みが許可されていないと保存できない
    func writeNutrition(_ write: HealthNutritionWrite) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let samples = Set(
            write.values.map { value -> HKSample in
                HKQuantitySample(
                    type: Self.quantityType(for: value.nutrient),
                    quantity: HKQuantity(
                        unit: Self.unit(for: value.nutrient), doubleValue: value.amount),
                    start: write.instant,
                    end: write.instant
                )
            })
        let food = HKCorrelation(
            type: Self.food,
            start: write.instant,
            end: write.instant,
            objects: samples,
            metadata: [
                HKMetadataKeyFoodType: write.foodName,
                HKMetadataKeySyncIdentifier: write.syncId.uuidString,
                HKMetadataKeySyncVersion: NSNumber(value: write.syncVersion),
                HKMetadataKeyTimeZone: write.timeZoneName,
            ]
        )
        try await store.save(food)
    }

    /// 同期 ID の組と、中のサンプルを消す。組を消しても中のサンプルが残るかは、実機で確かめる
    func deleteNutrition(syncId: UUID) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let handle = StoreHandle(store: store)
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: [syncId.uuidString]
            )
            let query = HKCorrelationQuery(
                type: Self.food, predicate: predicate, samplePredicates: nil
            ) { _, correlations, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var objects: [HKObject] = []
                for correlation in correlations ?? [] {
                    objects.append(correlation)
                    for sample in correlation.objects {
                        objects.append(sample)
                    }
                }
                // 空の配列は消せない（`errorInvalidArgument`）ので、見つからなければ何もしない
                guard !objects.isEmpty else {
                    continuation.resume()
                    return
                }
                handle.store.delete(objects) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            handle.store.execute(query)
        }
    }

    /// 許可を求め終えたあとに呼ぶ。起こされたときは `onWake` が、読み取りと送り待ちの送信を行う
    func startDeliveringUpdates(onWake: @escaping @Sendable () async -> Void) async {
        let shouldStart = deliveryState.withLock { state -> Bool in
            if case .started = state { return false }
            state = .started([])
            return true
        }
        guard shouldStart else { return }
        for type in [Self.bodyMass, Self.bodyFatPercentage] {
            try? await store.enableBackgroundDelivery(for: type, frequency: .immediate)
            let wake = onWake
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                let failed = error != nil
                let finish = ObserverCompletion(completion)
                Task {
                    if !failed {
                        await wake()
                    }
                    finish()
                }
            }
            deliveryState.withLock { state in
                guard case .started(var queries) = state else { return }
                queries.append(query)
                state = .started(queries)
            }
            store.execute(query)
        }
    }

    private let store = HKHealthStore()
    private let deliveryState = OSAllocatedUnfairLock(initialState: DeliveryState.notStarted)
    private static let bodyMass = HKQuantityType(.bodyMass)
    private static let bodyFatPercentage = HKQuantityType(.bodyFatPercentage)
    private static let kilogram = HKUnit.gramUnit(with: .kilo)
    private static let food = HKCorrelationType(.food)

    private var shareTypes: Set<HKSampleType> { [Self.bodyMass] }
    private var readTypes: Set<HKObjectType> { [Self.bodyMass, Self.bodyFatPercentage] }

    /// 水分を除いた栄養の種類。食品の組そのものは、許可を求められない
    private var nutritionShareTypes: Set<HKSampleType> {
        Set(
            HealthNutrient.allCases.map { nutrient -> HKSampleType in
                Self.quantityType(for: nutrient)
            })
    }

    private func authorizedBoundaries() async throws -> (bodyMass: Date?, bodyFat: Date?) {
        guard #available(iOS 27, *), HKHealthStore.isHealthDataAvailable() else {
            return (nil, nil)
        }
        let dates = try await store.earliestAuthorizedSampleDate(for: readTypes)
        return (
            dates.first { $0.key.identifier == Self.bodyMass.identifier }?.value,
            dates.first { $0.key.identifier == Self.bodyFatPercentage.identifier }?.value
        )
    }

    private func readQuantity(
        _ type: HKQuantityType,
        anchor: HKQueryAnchor?,
        notBefore: Date?
    ) async throws -> (
        samples: [HKQuantitySample], deletions: [HKDeletedObject], anchor: HKQueryAnchor
    ) {
        let predicate = notBefore.map {
            HKQuery.predicateForSamples(withStart: $0, end: nil, options: .strictStartDate)
        }
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            anchor: anchor
        )
        let result = try await descriptor.result(for: store)
        return (result.addedSamples, result.deletedObjects, result.newAnchor)
    }

    private func weightSample(_ sample: HKQuantitySample) -> HealthChanges.WeightSample {
        let source = sample.sourceRevision.source
        let zoneName = sample.metadata?[HKMetadataKeyTimeZone] as? String
        return HealthChanges.WeightSample(
            sampleId: sample.uuid,
            kilograms: sample.quantity.doubleValue(for: Self.kilogram),
            instant: sample.startDate,
            sourceAppName: source.name,
            sourceBundleId: source.bundleIdentifier,
            timeZone: zoneName.flatMap(TimeZone.init(identifier:))
        )
    }

    private func bodyFatSample(_ sample: HKQuantitySample) -> HealthChanges.BodyFatSample {
        HealthChanges.BodyFatSample(
            sampleId: sample.uuid,
            fraction: sample.quantity.doubleValue(for: .percent()),
            instant: sample.startDate,
            sourceBundleId: sample.sourceRevision.source.bundleIdentifier
        )
    }

    private static func quantityType(for nutrient: HealthNutrient) -> HKQuantityType {
        HKQuantityType(identifier(for: nutrient))
    }

    private static func identifier(for nutrient: HealthNutrient) -> HKQuantityTypeIdentifier {
        switch nutrient {
        case .energy: .dietaryEnergyConsumed
        case .protein: .dietaryProtein
        case .fat: .dietaryFatTotal
        case .carbohydrates: .dietaryCarbohydrates
        case .fiber: .dietaryFiber
        case .sodium: .dietarySodium
        case .cholesterol: .dietaryCholesterol
        case .potassium: .dietaryPotassium
        case .calcium: .dietaryCalcium
        case .magnesium: .dietaryMagnesium
        case .phosphorus: .dietaryPhosphorus
        case .iron: .dietaryIron
        case .zinc: .dietaryZinc
        case .copper: .dietaryCopper
        case .manganese: .dietaryManganese
        case .iodine: .dietaryIodine
        case .selenium: .dietarySelenium
        case .chromium: .dietaryChromium
        case .molybdenum: .dietaryMolybdenum
        case .vitaminA: .dietaryVitaminA
        case .vitaminD: .dietaryVitaminD
        case .vitaminE: .dietaryVitaminE
        case .vitaminK: .dietaryVitaminK
        case .thiamin: .dietaryThiamin
        case .riboflavin: .dietaryRiboflavin
        case .niacin: .dietaryNiacin
        case .vitaminB6: .dietaryVitaminB6
        case .vitaminB12: .dietaryVitaminB12
        case .folate: .dietaryFolate
        case .pantothenicAcid: .dietaryPantothenicAcid
        case .biotin: .dietaryBiotin
        case .vitaminC: .dietaryVitaminC
        }
    }

    private static func unit(for nutrient: HealthNutrient) -> HKUnit {
        switch nutrient.unit {
        case .kilocalorie: .kilocalorie()
        case .gram: .gram()
        case .milligram: .gramUnit(with: .milli)
        case .microgram: .gramUnit(with: .micro)
        }
    }

    private func laterDate(_ requested: Date?, _ authorized: Date?) -> Date? {
        switch (requested, authorized) {
        case (let requested?, let authorized?): max(requested, authorized)
        case (let requested?, nil): requested
        case (nil, let authorized?): authorized
        case (nil, nil): nil
        }
    }
}

/// 完了ハンドラは Sendable でないので、問い合わせの外へ送るときに包む
nonisolated private struct ObserverCompletion: @unchecked Sendable {
    init(_ completion: @escaping HKObserverQueryCompletionHandler) {
        self.completion = completion
    }

    func callAsFunction() {
        completion()
    }

    private let completion: HKObserverQueryCompletionHandler
}

/// 問い合わせの完了ハンドラの中で使うため、`Sendable` でない `HKHealthStore` を包む
nonisolated private struct StoreHandle: @unchecked Sendable {
    let store: HKHealthStore
}

nonisolated private enum DeliveryState {
    case notStarted
    case started([HKQuery])
}

nonisolated private struct StoredQueryAnchors: Codable {
    var bodyMass: Data?
    var bodyFat: Data?

    init(bodyMass: HKQueryAnchor, bodyFat: HKQueryAnchor) {
        self.bodyMass = try? NSKeyedArchiver.archivedData(
            withRootObject: bodyMass, requiringSecureCoding: true)
        self.bodyFat = try? NSKeyedArchiver.archivedData(
            withRootObject: bodyFat, requiringSecureCoding: true)
    }

    init(_ anchor: HealthAnchor?) {
        let stored = anchor.flatMap {
            try? JSONDecoder().decode(StoredQueryAnchors.self, from: $0.data)
        }
        bodyMass = stored?.bodyMass
        bodyFat = stored?.bodyFat
    }

    var bodyMassAnchor: HKQueryAnchor? { bodyMass.flatMap(Self.unarchive) }
    var bodyFatAnchor: HKQueryAnchor? { bodyFat.flatMap(Self.unarchive) }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    private static func unarchive(_ data: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}
