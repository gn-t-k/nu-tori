import NuToriCore

final class HealthAnchorStoreMock: HealthAnchorStore, @unchecked Sendable {
    private(set) var deleteCount = 0

    static func ok() -> HealthAnchorStoreMock {
        HealthAnchorStoreMock(failure: nil)
    }

    static func error(_ error: any Error) -> HealthAnchorStoreMock {
        HealthAnchorStoreMock(failure: error)
    }

    func deleteAll() async throws {
        try failIfNeeded()
        deleteCount += 1
    }

    private let failure: (any Error)?

    private init(failure: (any Error)?) {
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
