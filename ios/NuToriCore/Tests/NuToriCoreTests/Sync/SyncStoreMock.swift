import Foundation
import NuToriCore

final class SyncStoreMock: SyncStore, @unchecked Sendable {
    private(set) var records: [UUID: WeightRecord]
    private(set) var pending: [PendingWrite]
    private(set) var state: SyncState?
    private(set) var appliedChanges: [PulledChanges] = []
    private(set) var eraseAllCount = 0
    private(set) var healthState: HealthSyncState
    private(set) var appliedHealthImports: [HealthImportBatch] = []

    static func ok(
        records: [WeightRecord] = [],
        pendingWrites: [PendingWrite] = [],
        state: SyncState? = nil,
        healthState: HealthSyncState = .initial
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, pending: pendingWrites, state: state, healthState: healthState,
            failure: nil)
    }

    static func error(_ error: any Error) -> SyncStoreMock {
        SyncStoreMock(
            records: [], pending: [], state: nil, healthState: .initial, failure: error)
    }

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        try failIfNeeded()
        return records[id]
    }

    func weightRecords() async throws -> [WeightRecord] {
        try failIfNeeded()
        return Array(records.values)
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        try failIfNeeded()
        records[record.id] = record
        pending.append(write)
    }

    func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        try failIfNeeded()
        return pending
    }

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        try failIfNeeded()
        pending.removeAll { writeIds.contains($0.writeId) }
        for reversion in reversions {
            switch reversion {
            case .restore(let record): records[record.id] = record
            case .remove(let recordId): records[recordId] = nil
            }
        }
    }

    func syncState() async throws -> SyncState? {
        try failIfNeeded()
        return state
    }

    func saveSyncState(_ state: SyncState) async throws {
        try failIfNeeded()
        self.state = state
    }

    func apply(_ changes: PulledChanges) async throws {
        try failIfNeeded()
        for record in changes.records {
            records[record.id] = record
        }
        for recordId in changes.removedRecordIds {
            records[recordId] = nil
        }
        state = changes.state
        appliedChanges.append(changes)
    }

    func eraseAll() async throws {
        try failIfNeeded()
        records = [:]
        pending = []
        state = nil
        healthState = .initial
        eraseAllCount += 1
    }

    func healthSyncState() async throws -> HealthSyncState {
        try failIfNeeded()
        return healthState
    }

    func saveHealthSyncState(_ state: HealthSyncState) async throws {
        try failIfNeeded()
        healthState = state
    }

    func applyHealthImport(_ batch: HealthImportBatch) async throws {
        try failIfNeeded()
        for record in batch.records {
            records[record.id] = record
        }
        pending.append(contentsOf: batch.pendingWrites)
        healthState = batch.state
        appliedHealthImports.append(batch)
    }

    private let failure: (any Error)?

    private init(
        records: [WeightRecord],
        pending: [PendingWrite],
        state: SyncState?,
        healthState: HealthSyncState,
        failure: (any Error)?
    ) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        self.pending = pending
        self.state = state
        self.healthState = healthState
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
