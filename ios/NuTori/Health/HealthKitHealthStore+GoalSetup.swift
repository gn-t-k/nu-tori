import Foundation
import HealthKit
import NuToriCore

extension HealthKitHealthStore {
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
