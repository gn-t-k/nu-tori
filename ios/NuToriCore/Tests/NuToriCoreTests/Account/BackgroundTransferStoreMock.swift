import NuToriCore

final class BackgroundTransferStoreMock: BackgroundTransferStore, @unchecked Sendable {
    private(set) var cancelAndDeleteCount = 0

    static func ok() -> BackgroundTransferStoreMock {
        BackgroundTransferStoreMock()
    }

    func cancelAndDeleteAll() async throws {
        cancelAndDeleteCount += 1
    }
}
