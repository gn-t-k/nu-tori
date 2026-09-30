import Foundation
import NuToriAPI
public import NuToriCore

/// メモリの送り待ちの箱。送り待ちの箱の約束（保存の順、通し番号、全消去）を、保存の記録で確かめるために使う。
/// キャッシュは `Cache` を渡し、種類が当てる。保存のたびに `saves` へ足す
public actor MemorySyncBox<Cache: Sendable>: SyncBox {
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

    public private(set) var saves: [Save] = []
    public private(set) var state: SyncState?
    /// 今の道で当てた変更（記録の中身は持たない）
    public private(set) var appliedLegacy: [PulledChanges] = []
    public private(set) var appliedReversions: [RecordReversion] = []

    public nonisolated let recordKinds: [any SyncedRecordKind]

    public init(
        kinds: RecordKindRegistry<Cache>,
        cache: Cache,
        pendingEntries: [PendingEntry] = [],
        state: SyncState? = nil
    ) {
        self.kinds = kinds
        self.cache = cache
        self.entries = pendingEntries
        self.state = state
        self.recordKinds = kinds.synced
    }

    public func pendingEntries() -> [PendingEntry] {
        entries
    }

    public func apply(_ result: SyncBoxResult) throws {
        // 送り待ちを先に保存し、キャッシュをそのあとに保存する
        if !result.enqueuing.isEmpty {
            entries.append(contentsOf: result.enqueuing)
            saves.append(.pending(added: result.enqueuing.count, removed: 0))
        }
        try applyToCache(result)
        if !result.resolvedWriteIds.isEmpty {
            let removing = Set(result.resolvedWriteIds)
            entries.removeAll { removing.contains($0.writeId) }
            saves.append(.pending(added: 0, removed: removing.count))
        }
    }

    public func eraseAll() throws {
        saves.append(.pendingCleared(count: entries.count))
        entries = []
        for kind in kinds.kinds {
            try kind.erase(cache)
        }
        state = nil
        saves.append(.cacheCleared)
    }

    public func saveSyncState(_ state: SyncState) {
        self.state = state
        saves.append(.cache(changes: 0, afterSequence: state.afterSequence))
    }

    private let kinds: RecordKindRegistry<Cache>
    private let cache: Cache
    private var entries: [PendingEntry]

    private func applyToCache(_ result: SyncBoxResult) throws {
        var chunks: [(kind: any RecordKind<Cache>, changes: [SyncChange])] = []
        for group in result.kindChanges {
            guard let kind = kinds.kind(named: group.kind) else {
                throw UnknownRecordKindError(kind: group.kind)
            }
            for start in stride(from: 0, to: group.changes.count, by: Self.batchSize) {
                let end = min(start + Self.batchSize, group.changes.count)
                chunks.append((kind, Array(group.changes[start..<end])))
            }
        }
        appliedReversions.append(contentsOf: result.reversions)
        if let pulled = result.pulled {
            appliedLegacy.append(pulled)
        }
        let finalState = result.pulled?.state
        if chunks.isEmpty {
            guard !result.reversions.isEmpty || finalState != nil else { return }
            if let finalState { state = finalState }
            saves.append(.cache(changes: 0, afterSequence: finalState?.afterSequence))
            return
        }
        for (index, chunk) in chunks.enumerated() {
            try chunk.kind.apply(chunk.changes, to: cache)
            // 通し番号は、最後の保存で書く。途中で落ちても、書いていない変更を追い越さない
            let isLast = index == chunks.count - 1
            if isLast, let finalState { state = finalState }
            saves.append(
                .cache(
                    changes: chunk.changes.count,
                    afterSequence: isLast ? finalState?.afterSequence : nil))
        }
    }
}
