import NuToriCore

final class BackgroundTransferStoreMock: BackgroundTransferStore, @unchecked Sendable {
    private(set) var cancelAndDeleteCount = 0

    static func ok() -> BackgroundTransferStoreMock {
        BackgroundTransferStoreMock(failure: nil)
    }

    static func error(_ error: any Error) -> BackgroundTransferStoreMock {
        BackgroundTransferStoreMock(failure: error)
    }

    func cancelAndDeleteAll() async throws {
        try failIfNeeded()
        cancelAndDeleteCount += 1
    }

    private let failure: (any Error)?

    private init(failure: (any Error)?) {
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
