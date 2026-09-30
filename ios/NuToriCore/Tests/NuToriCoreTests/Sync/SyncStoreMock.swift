import Foundation
import NuToriCore

final class SyncStoreMock: SyncStore, @unchecked Sendable {
    private(set) var records: [UUID: WeightRecord]
    private(set) var settings: AccountSettings?
    private(set) var pending: [PendingWrite]
    private(set) var state: SyncState?
    private(set) var appliedChanges: [PulledChanges] = []
    private(set) var healthState: HealthSyncState
    private(set) var appliedHealthImports: [HealthImportBatch] = []
    private(set) var eraseAllCount = 0

    static func ok(
        records: [WeightRecord] = [],
        accountSettings: AccountSettings? = nil,
        pendingWrites: [PendingWrite] = [],
        state: SyncState? = nil,
        healthState: HealthSyncState = .initial
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, settings: accountSettings, pending: pendingWrites, state: state,
            healthState: healthState, failure: nil, writeFailure: nil)
    }

    static func error(
        _ error: any Error,
        records: [WeightRecord] = [],
        writesOnly: Bool = false
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, settings: nil, pending: [], state: nil, healthState: .initial,
            failure: writesOnly ? nil : error, writeFailure: writesOnly ? error : nil)
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
        try failWriteIfNeeded()
        records[record.id] = record
        pending.append(write)
    }

    func accountSettings() async throws -> AccountSettings? {
        try failIfNeeded()
        return settings
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        self.settings = settings
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
        try failWriteIfNeeded()
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
        try failWriteIfNeeded()
        self.state = state
    }

    func apply(_ changes: PulledChanges) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        for record in changes.records {
            records[record.id] = record
        }
        for recordId in changes.removedRecordIds {
            records[recordId] = nil
        }
        if let accountSettings = changes.accountSettings {
            settings = accountSettings
        }
        state = changes.state
        appliedChanges.append(changes)
    }

    func healthSyncState() async throws -> HealthSyncState {
        try failIfNeeded()
        return healthState
    }

    func saveHealthSyncState(_ state: HealthSyncState) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        healthState = state
    }

    func applyHealthImport(_ batch: HealthImportBatch) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        for record in batch.records {
            records[record.id] = record
        }
        pending.append(contentsOf: batch.pendingWrites)
        healthState = batch.state
        appliedHealthImports.append(batch)
    }

    func eraseAll() async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        records = [:]
        settings = nil
        pending = []
        state = nil
        healthState = .initial
        eraseAllCount += 1
    }

    private let failure: (any Error)?
    private let writeFailure: (any Error)?

    private init(
        records: [WeightRecord],
        settings: AccountSettings?,
        pending: [PendingWrite],
        state: SyncState?,
        healthState: HealthSyncState,
        failure: (any Error)?,
        writeFailure: (any Error)?
    ) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        self.settings = settings
        self.pending = pending
        self.state = state
        self.healthState = healthState
        self.failure = failure
        self.writeFailure = writeFailure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }

    private func failWriteIfNeeded() throws {
        if let writeFailure { throw writeFailure }
    }
}
