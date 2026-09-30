import Foundation
import NuToriCore

final class SyncStoreMock: SyncStore, @unchecked Sendable {
    private(set) var records: [UUID: WeightRecord]
    private(set) var settings: AccountSettings?
    private(set) var entries: [PendingEntry]
    /// 登録簿の種類に当てるよう渡された変更
    private(set) var appliedKindChanges: [KindChanges] = []
    let recordKinds: [any SyncedRecordKind]
    private(set) var state: SyncState?
    private(set) var appliedChanges: [PulledChanges] = []
    private(set) var healthState: HealthSyncState
    private(set) var appliedHealthImports: [HealthImportBatch] = []
    private(set) var eraseAllCount = 0

    /// 今の道の送り待ち。登録簿の種類の送り待ちは含まない
    var pending: [PendingWrite] {
        entries.compactMap { try? PendingWrite(entry: $0) }
    }

    static func ok(
        records: [WeightRecord] = [],
        accountSettings: AccountSettings? = nil,
        pendingWrites: [PendingWrite] = [],
        pendingEntries: [PendingEntry] = [],
        recordKinds: [any SyncedRecordKind] = [],
        state: SyncState? = nil,
        healthState: HealthSyncState = .initial
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, settings: accountSettings,
            entries: pendingWrites.map { try! $0.entry() } + pendingEntries, state: state,
            healthState: healthState, recordKinds: recordKinds, failure: nil, writeFailure: nil)
    }

    static func error(
        _ error: any Error,
        records: [WeightRecord] = [],
        writesOnly: Bool = false
    ) -> SyncStoreMock {
        SyncStoreMock(
            records: records, settings: nil, entries: [], state: nil, healthState: .initial,
            recordKinds: [],
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
        entries.append(try write.entry())
    }

    func accountSettings() async throws -> AccountSettings? {
        try failIfNeeded()
        return settings
    }

    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        self.settings = settings
        entries.append(try write.entry())
    }

    func pendingEntries() async throws -> [PendingEntry] {
        try failIfNeeded()
        // 古い順。同じ時刻は足した順
        return entries.enumerated().sorted {
            ($0.element.enqueuedAt, $0.offset) < ($1.element.enqueuedAt, $1.offset)
        }.map(\.element)
    }

    func apply(_ result: SyncBoxResult) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        entries.append(contentsOf: result.enqueuing)
        appliedKindChanges.append(contentsOf: result.kindChanges)
        for group in result.kindChanges where group.kind == AccountSettingsSyncKind.kindName {
            if let latest = AccountSettingsSyncKind.latestSettings(in: group.changes) {
                settings = latest
            }
        }
        if let changes = result.pulled {
            for record in changes.records {
                records[record.id] = record
            }
            for recordId in changes.removedRecordIds {
                records[recordId] = nil
            }
            state = changes.state
            appliedChanges.append(changes)
        }
        entries.removeAll { result.resolvedWriteIds.contains($0.writeId) }
        for reversion in result.reversions {
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
        entries.append(contentsOf: try batch.pendingWrites.map { try $0.entry() })
        healthState = batch.state
        appliedHealthImports.append(batch)
    }

    func eraseAll() async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        records = [:]
        settings = nil
        entries = []
        state = nil
        healthState = .initial
        eraseAllCount += 1
    }

    private let failure: (any Error)?
    private let writeFailure: (any Error)?

    private init(
        records: [WeightRecord],
        settings: AccountSettings?,
        entries: [PendingEntry],
        state: SyncState?,
        healthState: HealthSyncState,
        recordKinds: [any SyncedRecordKind],
        failure: (any Error)?,
        writeFailure: (any Error)?
    ) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        self.settings = settings
        self.entries = entries
        self.state = state
        self.healthState = healthState
        // アカウントの設定は、アプリでは登録簿の1行。ここでも登録簿の種類として持つ
        self.recordKinds = [AccountSettingsSyncKind()] + recordKinds
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
