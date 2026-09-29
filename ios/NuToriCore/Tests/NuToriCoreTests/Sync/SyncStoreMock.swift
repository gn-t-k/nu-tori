import Foundation
import NuToriCore

final class SyncStoreMock: SyncStore, @unchecked Sendable {
    private(set) var records: [UUID: WeightRecord]
    private(set) var settings: AccountSettings?
    private(set) var pending: [PendingWrite]
    private(set) var state: SyncState?
    private(set) var appliedChanges: [PulledChanges] = []

    static func ok(
        records: [WeightRecord] = [],
        accountSettings: AccountSettings? = nil,
        pendingWrites: [PendingWrite] = [],
        state: SyncState? = nil
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, settings: accountSettings, pending: pendingWrites, state: state,
            failure: nil)
    }

    static func error(_ error: any Error) -> SyncStoreMock {
        SyncStoreMock(records: [], settings: nil, pending: [], state: nil, failure: error)
    }

    func weightRecord(id: UUID) async throws -> WeightRecord? {
        try failIfNeeded()
        return records[id]
    }

    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws {
        try failIfNeeded()
        records[record.id] = record
        pending.append(write)
    }

    func accountSettings() async throws -> AccountSettings? {
        try failIfNeeded()
        return settings
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        try failIfNeeded()
        self.settings = settings
        pending.append(write)
    }

    func pendingWrites() async throws -> [PendingWrite] {
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
        if let accountSettings = changes.accountSettings {
            settings = accountSettings
        }
        state = changes.state
        appliedChanges.append(changes)
    }

    private let failure: (any Error)?

    private init(
        records: [WeightRecord],
        settings: AccountSettings?,
        pending: [PendingWrite],
        state: SyncState?,
        failure: (any Error)?
    ) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        self.settings = settings
        self.pending = pending
        self.state = state
        self.failure = failure
    }

    private func failIfNeeded() throws {
        if let failure { throw failure }
    }
}
