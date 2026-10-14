import Foundation
import NuToriCore

final class HealthStoreMock: HealthStore, @unchecked Sendable {
    private(set) var authorizationRequests = 0
    private(set) var readRequests: [ReadRequest] = []
    private(set) var writes: [HealthWeightWrite] = []
    private(set) var nutritionAuthorizationRequests = 0
    private(set) var nutritionWrites: [HealthNutritionWrite] = []
    private(set) var nutritionDeletions: [UUID] = []
    private(set) var goalSetupAuthorizationRequests = 0
    private(set) var dietaryEnergyReadRequests: [DailyReadRequest] = []
    private(set) var stepCountReadRequests: [DailyReadRequest] = []

    struct DailyReadRequest: Equatable {
        let days: ClosedRange<CalendarDay>
        let timeZone: TimeZone
    }

    /// 目標の設定で読むもの
    struct GoalSetup {
        var requestStatus = HealthAuthorizationRequestStatus.alreadyRequested
        var dietaryEnergy: [HealthDailySourceEnergy] = []
        var dietaryEnergyBoundary: Date?
        var dailySteps: [CalendarDay: Int] = [:]
        var stepCountBoundary: Date?
        var heightCentimeters: Double?
        var dateOfBirth: CalendarDay?
        var sex: BiologicalSex?
    }

    struct ReadRequest: Equatable {
        let anchor: HealthAnchor?
        let notBefore: Date?
    }

    static func ok(
        requestStatus: HealthAuthorizationRequestStatus = .alreadyRequested,
        isWriteAuthorized: Bool = true,
        earliestAuthorizedSampleDate: Date? = nil,
        changes: HealthChanges = .fixture(),
        nutritionRequestStatus: HealthAuthorizationRequestStatus = .alreadyRequested,
        authorizedNutrients: Set<HealthNutrient> = Set(HealthNutrient.allCases),
        nutritionFailure: (any Error)? = nil,
        goalSetup: GoalSetup = GoalSetup()
    ) -> HealthStoreMock {
        HealthStoreMock(
            requestStatus: requestStatus,
            isWriteAuthorized: isWriteAuthorized,
            earliestAuthorizedSampleDate: earliestAuthorizedSampleDate,
            changes: changes,
            nutritionRequestStatus: nutritionRequestStatus,
            authorizedNutrients: authorizedNutrients,
            nutritionFailure: nutritionFailure,
            goalSetup: goalSetup,
            failure: nil
        )
    }

    static func error(_ error: any Error) -> HealthStoreMock {
        HealthStoreMock(
            requestStatus: .alreadyRequested,
            isWriteAuthorized: true,
            earliestAuthorizedSampleDate: nil,
            changes: .fixture(),
            nutritionRequestStatus: .alreadyRequested,
            authorizedNutrients: Set(HealthNutrient.allCases),
            nutritionFailure: nil,
            goalSetup: GoalSetup(),
            failure: error
        )
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        try failIfNeeded()
        return requestStatus
    }

    func requestAuthorization() async throws {
        try failIfNeeded()
        authorizationRequests += 1
    }

    func isWeightWriteAuthorized() async throws -> Bool {
        try failIfNeeded()
        return isWriteAuthorized
    }

    func earliestAuthorizedSampleDate() async throws -> Date? {
        try failIfNeeded()
        return earliestAuthorizedSampleDateValue
    }

    func readWeightChanges(after anchor: HealthAnchor?, notBefore: Date?) async throws
        -> HealthChanges
    {
        try failIfNeeded()
        readRequests.append(ReadRequest(anchor: anchor, notBefore: notBefore))
        return changes
    }

    func writeWeight(_ write: HealthWeightWrite) async throws {
        try failIfNeeded()
        writes.append(write)
    }

    func nutritionAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        try failIfNeeded()
        return nutritionRequestStatus
    }

    func requestNutritionAuthorization() async throws {
        try failIfNeeded()
        nutritionAuthorizationRequests += 1
    }

    func writeAuthorizedNutrients() async throws -> Set<HealthNutrient> {
        try failIfNeeded()
        return authorizedNutrients
    }

    func writeNutrition(_ write: HealthNutritionWrite) async throws {
        try failIfNeeded()
        if let nutritionFailure { throw nutritionFailure }
        nutritionWrites.append(write)
    }

    func deleteNutrition(syncId: UUID) async throws {
        try failIfNeeded()
        if let nutritionFailure { throw nutritionFailure }
        nutritionDeletions.append(syncId)
    }

    func goalSetupAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        try failIfNeeded()
        return goalSetup.requestStatus
    }

    func requestGoalSetupAuthorization() async throws {
        try failIfNeeded()
        goalSetupAuthorizationRequests += 1
    }

    func earliestAuthorizedSampleDate(for quantity: HealthDailyQuantity) async throws -> Date? {
        try failIfNeeded()
        switch quantity {
        case .dietaryEnergy: return goalSetup.dietaryEnergyBoundary
        case .stepCount: return goalSetup.stepCountBoundary
        }
    }

    func readDailyDietaryEnergyBySource(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [HealthDailySourceEnergy]
    {
        try failIfNeeded()
        dietaryEnergyReadRequests.append(DailyReadRequest(days: days, timeZone: timeZone))
        return goalSetup.dietaryEnergy
    }

    func readDailyStepCounts(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
        async throws -> [CalendarDay: Int]
    {
        try failIfNeeded()
        stepCountReadRequests.append(DailyReadRequest(days: days, timeZone: timeZone))
        return goalSetup.dailySteps
    }

    func readLatestHeightCentimeters() async throws -> Double? {
        try failIfNeeded()
        return goalSetup.heightCentimeters
    }

    func readDateOfBirth() async throws -> CalendarDay? {
        try failIfNeeded()
        return goalSetup.dateOfBirth
    }

    func readBiologicalSex() async throws -> BiologicalSex? {
        try failIfNeeded()
        return goalSetup.sex
    }

    private let requestStatus: HealthAuthorizationRequestStatus
    private let isWriteAuthorized: Bool
    private let earliestAuthorizedSampleDateValue: Date?
    private let changes: HealthChanges
    private let nutritionRequestStatus: HealthAuthorizationRequestStatus
    private let authorizedNutrients: Set<HealthNutrient>
    private let nutritionFailure: (any Error)?
    private let goalSetup: GoalSetup
    private let failure: (any Error)?

    private init(
        requestStatus: HealthAuthorizationRequestStatus,
        isWriteAuthorized: Bool,
        earliestAuthorizedSampleDate: Date?,
        changes: HealthChanges,
        nutritionRequestStatus: HealthAuthorizationRequestStatus,
        authorizedNutrients: Set<HealthNutrient>,
        nutritionFailure: (any Error)?,
        goalSetup: GoalSetup,
        failure: (any Error)?
    ) {
        self.requestStatus = requestStatus
        self.isWriteAuthorized = isWriteAuthorized
        earliestAuthorizedSampleDateValue = earliestAuthorizedSampleDate
        self.changes = changes
        self.nutritionRequestStatus = nutritionRequestStatus
        self.authorizedNutrients = authorizedNutrients
        self.nutritionFailure = nutritionFailure
        self.goalSetup = goalSetup
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
