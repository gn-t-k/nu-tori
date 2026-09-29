import Foundation
import NuToriCore

final class HealthStoreMock: HealthStore, @unchecked Sendable {
    private(set) var authorizationRequests = 0
    private(set) var readRequests: [ReadRequest] = []
    private(set) var writes: [HealthWeightWrite] = []

    struct ReadRequest: Equatable {
        let anchor: HealthAnchor?
        let notBefore: Date?
    }

    static func ok(
        requestStatus: HealthAuthorizationRequestStatus = .alreadyRequested,
        isWriteAuthorized: Bool = true,
        earliestAuthorizedSampleDate: Date? = nil,
        changes: HealthChanges = .fixture()
    ) -> HealthStoreMock {
        HealthStoreMock(
            requestStatus: requestStatus,
            isWriteAuthorized: isWriteAuthorized,
            earliestAuthorizedSampleDate: earliestAuthorizedSampleDate,
            changes: changes,
            failure: nil
        )
    }

    static func error(_ error: any Error) -> HealthStoreMock {
        HealthStoreMock(
            requestStatus: .alreadyRequested,
            isWriteAuthorized: true,
            earliestAuthorizedSampleDate: nil,
            changes: .fixture(),
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

    private let requestStatus: HealthAuthorizationRequestStatus
    private let isWriteAuthorized: Bool
    private let earliestAuthorizedSampleDateValue: Date?
    private let changes: HealthChanges
    private let failure: (any Error)?

    private init(
        requestStatus: HealthAuthorizationRequestStatus,
        isWriteAuthorized: Bool,
        earliestAuthorizedSampleDate: Date?,
        changes: HealthChanges,
        failure: (any Error)?
    ) {
        self.requestStatus = requestStatus
        self.isWriteAuthorized = isWriteAuthorized
        earliestAuthorizedSampleDateValue = earliestAuthorizedSampleDate
        self.changes = changes
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
