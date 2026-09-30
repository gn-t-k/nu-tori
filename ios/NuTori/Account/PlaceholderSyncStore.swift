import Foundation
import NuToriCore

/// SwiftData の保存ができるまでの置き場。記録を持てないので、書き込みは投げる
nonisolated struct PlaceholderSyncStore: SyncStore {
    let queuedWrites: [PendingWrite]
    let hasCompletedInitialPull: Bool

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        nil
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        throw StoreNotAvailableError()
    }

    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        queuedWrites
    }

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        throw StoreNotAvailableError()
    }

    func syncState() async throws -> SyncState? {
        SyncState(
            afterSequence: 0,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKindsVersion: 0,
            startedOn: nil
        )
    }

    func saveSyncState(_ state: SyncState) async throws {
        throw StoreNotAvailableError()
    }

    func apply(_ changes: PulledChanges) async throws {
        throw StoreNotAvailableError()
    }

    func eraseAll() async throws {}

    struct StoreNotAvailableError: Error {}
}
