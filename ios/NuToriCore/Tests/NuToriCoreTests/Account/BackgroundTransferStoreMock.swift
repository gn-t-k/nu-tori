import NuToriCore

final class BackgroundTransferStoreMock: BackgroundTransferStore, @unchecked Sendable {
    private(set) var cancelUploadsCount = 0
    private(set) var cancelAndDeleteCount = 0

    static func ok(log: CallLog = CallLog()) -> BackgroundTransferStoreMock {
        BackgroundTransferStoreMock(failure: nil, log: log)
    }

    static func error(_ error: any Error) -> BackgroundTransferStoreMock {
        BackgroundTransferStoreMock(failure: error, log: CallLog())
    }

    func cancelUploads() async {
        log.record("backgroundTransfers.cancelUploads")
        cancelUploadsCount += 1
    }

    func cancelAndDeleteAll() async throws {
        try failIfNeeded()
        log.record("backgroundTransfers.cancelAndDeleteAll")
        cancelAndDeleteCount += 1
    }

    private let failure: (any Error)?
    private let log: CallLog

    private init(failure: (any Error)?, log: CallLog) {
        self.failure = failure
        self.log = log
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
