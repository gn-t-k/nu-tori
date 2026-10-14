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

    /// 食品の組（食品名は `HKMetadataKeyFoodType`）で書く。組は、中の種類の書き込みが許可されていないと保存できない。
    /// 中のサンプルにも時間帯と版を付け、同期 ID は組の同期 ID に種類を足して分ける。版を上げて書き直したとき、中のサンプルも置き換わるため
    func writeNutrition(_ write: HealthNutritionWrite) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let samples = Set(
            write.values.map { value -> HKSample in
                let type = Self.quantityType(for: value.nutrient)
                return HKQuantitySample(
                    type: type,
                    quantity: HKQuantity(
                        unit: Self.unit(for: value.nutrient), doubleValue: value.amount),
                    start: write.instant,
                    end: write.instant,
                    metadata: [
                        HKMetadataKeySyncIdentifier: Self.sampleSyncIdentifier(
                            syncId: write.syncId, type: type),
                        HKMetadataKeySyncVersion: NSNumber(value: write.syncVersion),
                        HKMetadataKeyTimeZone: write.timeZoneName,
                    ]
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
        let descriptor = HKSampleQueryDescriptor(
            predicates: [
                .correlation(
                    type: Self.food,
                    predicate: HKQuery.predicateForObjects(
                        withMetadataKey: HKMetadataKeySyncIdentifier,
                        allowedValues: [syncId.uuidString]
                    ))
            ],
            sortDescriptors: []
        )
        var objects: [HKObject] = []
        for correlation in try await descriptor.result(for: store) {
            objects.append(correlation)
            for sample in correlation.objects {
                objects.append(sample)
            }
        }
        // 空の配列は消せない（`errorInvalidArgument`）ので、見つからなければ何もしない
        guard !objects.isEmpty else { return }
        try await store.delete(objects)
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

    func goalSetupAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .alreadyRequested }
        switch try await store.statusForAuthorizationRequest(
            toShare: Self.goalSetupShareTypes, read: Self.goalSetupReadTypes)
        {
        case .shouldRequest, .unknown:
            return .notYetRequested
        case .unnecessary:
            return .alreadyRequested
        @unknown default:
            return .notYetRequested
        }
    }

    /// 体重と体脂肪率も一緒に渡す。ヘルスケアは、まだ求めていない種類だけを画面に出す
    func requestGoalSetupAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(
            toShare: Self.goalSetupShareTypes, read: Self.goalSetupReadTypes)
    }

    func earliestAuthorizedSampleDate(for quantity: HealthDailyQuantity) async throws -> Date? {
        guard #available(iOS 27, *), HKHealthStore.isHealthDataAvailable() else { return nil }
        let type = Self.quantityType(for: quantity)
        let dates = try await store.earliestAuthorizedSampleDate(for: [type])
        return dates.first { $0.key.identifier == type.identifier }?.value
    }

    /// 食品の組をたどらず、量のサンプルの統計で出どころごとに合計する
    func readDailyDietaryEnergyBySource(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [HealthDailySourceEnergy]
    {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        var totals: [HealthDailySourceEnergy] = []
        for statistics in try await dailyStatistics(
            of: .dietaryEnergy, options: [.cumulativeSum, .separateBySource], days: days,
            in: timeZone)
        {
            let day = CalendarDay(containing: statistics.startDate, in: timeZone)
            for source in statistics.sources ?? [] {
                guard let sum = statistics.sumQuantity(for: source) else { continue }
                totals.append(
                    HealthDailySourceEnergy(
                        day: day,
                        sourceBundleId: source.bundleIdentifier,
                        kilocalories: sum.doubleValue(for: .kilocalorie())
                    ))
            }
        }
        return totals
    }

    func readDailyStepCounts(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [CalendarDay: Int]
    {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        var steps: [CalendarDay: Int] = [:]
        for statistics in try await dailyStatistics(
            of: .stepCount, options: .cumulativeSum, days: days, in: timeZone)
        {
            guard let sum = statistics.sumQuantity() else { continue }
            steps[CalendarDay(containing: statistics.startDate, in: timeZone)] = Int(
                sum.doubleValue(for: .count()).rounded())
        }
        return steps
    }

    func readLatestHeightCentimeters() async throws -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.height))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: store).first?.quantity.doubleValue(
            for: .meterUnit(with: .centi))
    }

    /// 許可されていないときに投げるか空で返すかは版で違うので、どちらも読めなかったものにする
    func readDateOfBirth() async throws -> CalendarDay? {
        guard HKHealthStore.isHealthDataAvailable(),
            let components = try? store.dateOfBirthComponents(),
            let year = components.year, let month = components.month, let day = components.day
        else {
            return nil
        }
        return CalendarDay(year: year, month: month, day: day)
    }

    func readBiologicalSex() async throws -> BiologicalSex? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        switch (try? store.biologicalSex())?.biologicalSex {
        case .male: return .male
        case .female: return .female
        case .notSet, .other, nil: return nil
        @unknown default: return nil
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

    private static func sampleSyncIdentifier(syncId: UUID, type: HKQuantityType) -> String {
        "\(syncId.uuidString)/\(type.identifier)"
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

    private static let goalSetupShareTypes: Set<HKSampleType> = [HKQuantityType(.bodyMass)]
    private static let goalSetupReadTypes: Set<HKObjectType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.height),
        HKCharacteristicType(.dateOfBirth),
        HKCharacteristicType(.biologicalSex),
        HKQuantityType(.stepCount),
        HKQuantityType(.dietaryEnergyConsumed),
    ]

    private static func quantityType(for quantity: HealthDailyQuantity) -> HKQuantityType {
        switch quantity {
        case .dietaryEnergy: HKQuantityType(.dietaryEnergyConsumed)
        case .stepCount: HKQuantityType(.stepCount)
        }
    }

    /// サンプルの無い日は、統計が合計を持たない
    private func dailyStatistics(
        of quantity: HealthDailyQuantity,
        options: HKStatisticsOptions,
        days: ClosedRange<CalendarDay>,
        in timeZone: TimeZone
    ) async throws -> [HKStatistics] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let first = days.lowerBound
        let afterLast = days.upperBound.advanced(by: 1)
        guard
            let start = calendar.date(
                from: DateComponents(year: first.year, month: first.month, day: first.day)),
            let end = calendar.date(
                from: DateComponents(
                    year: afterLast.year, month: afterLast.month, day: afterLast.day))
        else {
            return []
        }
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: Self.quantityType(for: quantity),
                predicate: HKQuery.predicateForSamples(
                    withStart: start, end: end, options: .strictStartDate)
            ),
            options: options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        return try await descriptor.result(for: store).statistics()
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
