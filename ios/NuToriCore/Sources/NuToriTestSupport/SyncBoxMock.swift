public import Foundation
import NuToriAPI
public import NuToriCore
import Synchronization

/// メモリの送り待ちの箱。送り待ちの箱の約束（保存の順、通し番号、全消去）を、保存の記録で確かめるために使う。
/// 保存の順は本物の箱と同じ `SyncBoxSaveOrder` が決める。キャッシュは `Cache` を渡し、種類が当てる。保存のたびに `saves` へ足す。
/// 失敗を渡すと、読み書きの失敗を確かめられる
public final class SyncBoxMock<Cache: Sendable>: SyncBox {
    /// 1回の保存
    public enum Save: Sendable, Equatable {
        /// 送り待ちの置き場への保存（ヘルスケアの同期の進み具合を書く保存も含む）
        case pending(added: Int, removed: Int)
        /// 送り待ちの置き場を空にする保存
        case pendingCleared(count: Int)
        /// キャッシュの置き場への保存。`afterSequence` はこの保存で書いた通し番号
        case cache(changes: Int, afterSequence: Int?)
        case cacheCleared
    }

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
    /// ヘルスケアに書いた料理の ID ごとの、書いた版
    public var healthDishWrites: [UUID: Int] { storage.withLock { $0.healthDishWrites } }

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
            if let syncState = result.syncState {
                storage.appliedSyncStates.append(syncState)
            }
            // 知らない種類の手前までを、当てるよう渡された変更として残す
            storage.appliedKindChanges.append(
                contentsOf: result.kindChanges.prefix { kinds.kind(named: $0.kind) != nil })
            try SyncBoxSaveOrder.apply(
                result, kinds: kinds, cache: cache,
                savePending: { enqueuing, healthSyncState in
                    storage.entries.append(contentsOf: enqueuing)
                    if let healthSyncState {
                        storage.healthState = healthSyncState
                    }
                    storage.saves.append(.pending(added: enqueuing.count, removed: 0))
                },
                saveCache: { changeCount, syncState in
                    if let syncState {
                        storage.state = syncState
                    }
                    storage.saves.append(
                        .cache(changes: changeCount, afterSequence: syncState?.afterSequence))
                },
                removePending: { writeIds in
                    storage.entries.removeAll { writeIds.contains($0.writeId) }
                    storage.saves.append(.pending(added: 0, removed: writeIds.count))
                })
        }
    }

    public func eraseAll() async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        try storage.withLock { storage in
            storage.saves.append(.pendingCleared(count: storage.entries.count))
            storage.entries = []
            storage.healthState = .initial
            storage.healthDishWrites = [:]
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
        var healthDishWrites: [UUID: Int] = [:]
        var eraseAllCount = 0
    }

    private let kinds: RecordKindRegistry<Cache>
    private let failure: (any Error)?
    private let writeFailure: (any Error)?
    private let storage: Mutex<Storage>
}

extension SyncBoxMock: RecordCacheReading {
    public func read<Syncing: CacheApplying, Value: Sendable>(
        _ kind: Syncing.Type,
        _ body: @Sendable (Syncing.Cache) throws -> Value
    ) async throws -> Value {
        try failIfNeeded()
        return try body(try kinds.port(kind, in: cache))
    }
}

extension SyncBoxMock: HealthDishWriteStoring where Cache == RecordCacheMock {
    public func dishVersionsWrittenToHealth() async throws -> [UUID: Int] {
        try failIfNeeded()
        return healthDishWrites
    }

    public func markDishWrittenToHealth(dishId: UUID, version: Int) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        withStorage { $0.healthDishWrites[dishId] = version }
    }

    public func unmarkDishWrittenToHealth(dishId: UUID) async throws {
        try failIfNeeded()
        try failWriteIfNeeded()
        withStorage { $0.healthDishWrites[dishId] = nil }
    }
}

extension SyncBoxMock: HealthSyncStoring where Cache == RecordCacheMock {
    public func healthSyncState() async throws -> HealthSyncState {
        try failIfNeeded()
        return healthState
    }
}
