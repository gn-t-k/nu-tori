import NuToriCore

final class HealthAnchorStoreMock: HealthAnchorStore, @unchecked Sendable {
    private(set) var deleteCount = 0

    static func ok() -> HealthAnchorStoreMock {
        HealthAnchorStoreMock()
    }

    func deleteAll() async throws {
        deleteCount += 1
    }
}
