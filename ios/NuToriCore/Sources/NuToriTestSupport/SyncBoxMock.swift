public import Foundation
import NuToriAPI
public import NuToriCore
import Synchronization

/// メモリの送り待ちの箱。送り待ちの箱の約束（保存の順、通し番号、全消去）を、保存の記録で確かめるために使う。
/// キャッシュは `Cache` を渡し、種類が当てる。保存のたびに `saves` へ足す。
/// 失敗を渡すと、読み書きの失敗を確かめられる
public final class SyncBoxMock<Cache: Sendable>: SyncBox {
    /// 1回の保存
    public enum Save: Sendable, Equatable {
        /// 送り待ちの置き場への保存
        case pending(added: Int, removed: Int)
        /// 送り待ちの置き場を空にする保存
        case pendingCleared(count: Int)
        /// キャッシュの置き場への保存。`afterSequence` はこの保存で書いた通し番号
        case cache(changes: Int, afterSequence: Int?)
        case cacheCleared
    }

    /// 100 件ずつ分けて保存する（本物の箱に合わせる）
    public static var batchSize: Int { 100 }

    public let cache: Cache
    public let recordKinds: [any SyncedRecordKind]

    /// - Parameters:
    ///   - failure: 渡すと、読みも書きも、この失敗で投げる
    ///   - writeFailure: 渡すと、書きだけ、この失敗で投げる
    public init(
        kinds: RecordKindRegistry<Cache>,
        cache: Cache,
        pendingEntries: [PendingEntry] = [],
        state: SyncState? = nil,
        healthState: HealthSyncState = .initial,
        failure: (any Error)? = nil,
        writeFailure: (any Error)? = nil
    ) {
        self.kinds = kinds
        self.cache = cache
        self.recordKinds = kinds.synced
        self.failure = failure
        self.writeFailure = writeFailure
        self.storage = Mutex(
            Storage(entries: pendingEntries, state: state, healthState: healthState))
    }

    public var saves: [Save] { storage.withLock { $0.saves } }
    public var state: SyncState? { storage.withLock { $0.state } }
    /// 送り待ちを足した順。`pendingEntries()` は古い順
    public var entries: [PendingEntry] { storage.withLock { $0.entries } }
    /// 種類に当てるよう渡された変更
    public var appliedKindChanges: [KindChanges] { storage.withLock { $0.appliedKindChanges } }
    /// 同期の状態を書くよう渡された結果ごとの状態
    public var appliedSyncStates: [SyncState] { storage.withLock { $0.appliedSyncStates } }
    public var eraseAllCount: Int { storage.withLock { $0.eraseAllCount } }
    public var healthState: HealthSyncState { storage.withLock { $0.healthState } }
    public var appliedHealthImports: [HealthImportBatch] {
        storage.withLock { $0.appliedHealthImports }
    }

    public func pendingEntries() async throws -> [PendingEntry] {
        try failIfNeeded()
        // 古い順。同じ時刻は足した順
        return storage.withLock { storage in
            storage.entries.enumerated().sorted {
                ($0.element.enqueuedAt, $0.offset) < ($1.element.enqueuedAt, $1.offset)
            }.map(\.element)
        }
    }

    public func syncState() async throws -> SyncState? {
        try failIfNeeded()
        return state
    }

    public func apply(_ result: SyncBoxResult) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        try storage.withLock { storage in
            // 送り待ちを先に保存し、キャッシュをそのあとに保存する
            if !result.enqueuing.isEmpty {
                storage.entries.append(contentsOf: result.enqueuing)
                storage.saves.append(.pending(added: result.enqueuing.count, removed: 0))
            }
            if let syncState = result.syncState {
                storage.appliedSyncStates.append(syncState)
            }
            try applyToCache(result, in: &storage)
            if !result.resolvedWriteIds.isEmpty {
                let removing = Set(result.resolvedWriteIds)
                storage.entries.removeAll { removing.contains($0.writeId) }
                storage.saves.append(.pending(added: 0, removed: removing.count))
            }
        }
    }

    public func eraseAll() async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        try storage.withLock { storage in
            storage.saves.append(.pendingCleared(count: storage.entries.count))
            storage.entries = []
            storage.healthState = .initial
            for kind in kinds.kinds {
                try kind.erase(cache)
            }
            storage.state = nil
            storage.saves.append(.cacheCleared)
            storage.eraseAllCount += 1
        }
    }

    func failIfNeeded() throws {
        if let failure { throw failure }
    }

    func failWriteIfNeeded() throws {
        if let writeFailure { throw writeFailure }
    }

    func withStorage(_ body: (inout Storage) -> Void) {
        storage.withLock { body(&$0) }
    }

    struct Storage: Sendable {
        var entries: [PendingEntry]
        var state: SyncState?
        var healthState: HealthSyncState
        var saves: [Save] = []
        var appliedKindChanges: [KindChanges] = []
        var appliedSyncStates: [SyncState] = []
        var appliedHealthImports: [HealthImportBatch] = []
        var eraseAllCount = 0
    }

    private let kinds: RecordKindRegistry<Cache>
    private let failure: (any Error)?
    private let writeFailure: (any Error)?
    private let storage: Mutex<Storage>

    private func applyToCache(_ result: SyncBoxResult, in storage: inout Storage) throws {
        var chunks: [(kind: any RecordKind<Cache>, changes: [SyncChange])] = []
        for group in result.kindChanges {
            guard let kind = kinds.kind(named: group.kind) else {
                throw UnknownRecordKindError.notRegistered(group.kind)
            }
            storage.appliedKindChanges.append(group)
            for start in stride(from: 0, to: group.changes.count, by: Self.batchSize) {
                let end = min(start + Self.batchSize, group.changes.count)
                chunks.append((kind, Array(group.changes[start..<end])))
            }
        }
        let finalState = result.syncState
        if chunks.isEmpty {
            guard let finalState else { return }
            storage.state = finalState
            storage.saves.append(.cache(changes: 0, afterSequence: finalState.afterSequence))
            return
        }
        for (index, chunk) in chunks.enumerated() {
            try chunk.kind.apply(chunk.changes, to: cache)
            // 通し番号は、最後の保存で書く。途中で落ちても、書いていない変更を追い越さない
            let isLast = index == chunks.count - 1
            if isLast, let finalState { storage.state = finalState }
            storage.saves.append(
                .cache(
                    changes: chunk.changes.count,
                    afterSequence: isLast ? finalState?.afterSequence : nil))
        }
    }
}

extension SyncBoxMock: RecordCacheReading where Cache == RecordCacheMock {
    public func weightRecord(id: UUID) async throws -> WeightRecord? {
        try failIfNeeded()
        return cache.records[id]
    }

    public func weightRecords() async throws -> [WeightRecord] {
        try failIfNeeded()
        return Array(cache.records.values)
    }

    public func accountSettings() async throws -> AccountSettings? {
        try failIfNeeded()
        return cache.settings
    }

    public func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus] {
        try failIfNeeded()
        return cache.estimationStatuses
    }
}

extension SyncBoxMock: HealthSyncStoring where Cache == RecordCacheMock {
    public func healthSyncState() async throws -> HealthSyncState {
        try failIfNeeded()
        return healthState
    }

    public func saveHealthSyncState(_ state: HealthSyncState) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        withStorage { $0.healthState = state }
    }

    public func applyHealthImport(_ batch: HealthImportBatch) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        let entries = try batch.pendingWrites.map { try $0.entry() }
        for record in batch.records {
            cache.upsert(record)
        }
        withStorage {
            $0.entries.append(contentsOf: entries)
            $0.healthState = batch.state
            $0.appliedHealthImports.append(batch)
        }
    }
}
