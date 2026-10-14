public import Foundation

/// 初めて目標を立てるときの、ヘルスケアの許可と読み取り。読んだ値は持たず、呼んだ側が目標が決まった時点で捨てる
public struct GoalSetupHealthReader: Sendable {
    public init(
        healthStore: any HealthStore,
        ownBundleId: String,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        errorReporting: any ErrorReportingSession
    ) {
        self.healthStore = healthStore
        self.ownBundleId = ownBundleId
        self.timeZone = timeZone
        self.now = now
        self.errorReporting = errorReporting
    }

    public func hasUnrequestedAuthorization() async throws -> Bool {
        switch try await healthStore.goalSetupAuthorizationRequestStatus() {
        case .notYetRequested: true
        case .alreadyRequested: false
        }
    }

    public func requestAuthorization() async throws {
        try await healthStore.requestGoalSetupAuthorization()
    }

    /// 初期値の窓に入る使い始める前の日の、摂取エネルギー（kcal）。
    /// 読めなかった日（サンプルが無い、nu-tori の分しか無い、読み取りの期間の境界より前）は入れず、0 にしない
    public func intakeEnergyBeforeFirstUse(firstUseDay: CalendarDay) async throws
        -> [CalendarDay: Double]
    {
        let zone = timeZone()
        let window = Self.initialWindow(endingBefore: CalendarDay(containing: now(), in: zone))
        let lastDayBeforeFirstUse = min(window.upperBound, firstUseDay.advanced(by: -1))
        guard window.lowerBound <= lastDayBeforeFirstUse else { return [:] }
        let days = window.lowerBound...lastDayBeforeFirstUse
        let (totals, boundary) = try await reporting {
            (
                try await healthStore.readDailyDietaryEnergyBySource(days: days, in: zone),
                try await healthStore.earliestAuthorizedSampleDate(for: .dietaryEnergy)
            )
        }
        var largest: [CalendarDay: Double] = [:]
        for total in totals where total.sourceBundleId != ownBundleId {
            largest[total.day] = max(largest[total.day] ?? total.kilocalories, total.kilocalories)
        }
        return largest.filter { Self.isWhollyAuthorized($0.key, in: zone, boundary: boundary) }
    }

    public func bodyData() async throws -> HealthBodyData {
        let zone = timeZone()
        let today = CalendarDay(containing: now(), in: zone)
        return try await reporting {
            let steps = try await healthStore.readDailyStepCounts(
                days: Self.initialWindow(endingBefore: today), in: zone)
            let boundary = try await healthStore.earliestAuthorizedSampleDate(for: .stepCount)
            return HealthBodyData(
                heightCentimeters: try await healthStore.readLatestHeightCentimeters(),
                age: try await healthStore.readDateOfBirth().map {
                    AgeInYears.completed(since: $0, on: today)
                },
                sex: try await healthStore.readBiologicalSex(),
                dailySteps: steps.filter {
                    Self.isWhollyAuthorized($0.key, in: zone, boundary: boundary)
                }
            )
        }
    }

    private let healthStore: any HealthStore
    private let ownBundleId: String
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let errorReporting: any ErrorReportingSession

    /// 初期値の窓（今日を除く直前の 28 日）。サーバーの推定消費カロリーの始まりの計算と同じ幅
    private static func initialWindow(endingBefore today: CalendarDay) -> ClosedRange<CalendarDay> {
        today.advanced(by: -28)...today.advanced(by: -1)
    }

    /// 境界をまたぐ日は、日の合計が一部しか読めていないので、読めなかった日にする
    private static func isWhollyAuthorized(
        _ day: CalendarDay, in timeZone: TimeZone, boundary: Date?
    ) -> Bool {
        guard let boundary else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: day.year, month: day.month, day: day.day)
        guard let start = calendar.date(from: components) else { return false }
        return start >= boundary
    }

    private func reporting<T: Sendable>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch {
            await errorReporting.report(error, as: .healthRead)
            throw error
        }
    }
}
