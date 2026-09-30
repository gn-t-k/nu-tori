import Foundation
import NuToriAPI
import NuToriCore
import SwiftData
import Synchronization

/// 種類の名前が `note` の、テスト用の登録簿の1行。サーバーの `note` の変更（`SyncChange.unknown`）を持つ。
/// キャッシュには何も書かず、当てられた数を数える
nonisolated struct RecordKindMock: RecordKind {
    nonisolated struct Failure: Error, Equatable {}

    /// 種類が当てられた数と、全消去された回数
    nonisolated final class Log: Sendable {
        var appliedChangeCount: Int { applied.withLock { $0 } }
        var eraseCount: Int { erased.withLock { $0 } }

        fileprivate func didApply(_ count: Int) { applied.withLock { $0 += count } }
        fileprivate func didErase() { erased.withLock { $0 += 1 } }

        private let applied = Mutex(0)
        private let erased = Mutex(0)
    }

    let name = "note"
    let log: Log
    let failure: Failure?

    static func ok(log: Log = Log()) -> RecordKindMock {
        RecordKindMock(log: log, failure: nil)
    }

    static func error(_ failure: Failure, log: Log = Log()) -> RecordKindMock {
        RecordKindMock(log: log, failure: failure)
    }

    static func entry(writeId: UUID = UUID(), enqueuedAt: Date = Date(timeIntervalSince1970: 0))
        -> PendingEntry
    {
        PendingEntry(writeId: writeId, enqueuedAt: enqueuedAt, kind: "note", content: Data([0x01]))
    }

    static let change = SyncChange.unknown(kind: "note")

    func owns(_ change: SyncChange) -> Bool {
        if case .unknown(let kind) = change { kind == name } else { false }
    }

    func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        .sourceDeletedWeightRecord(writeId: entry.writeId, weightRecordId: UUID())
    }

    func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        revertedRecordIds: inout Set<UUID>
    ) throws -> KindRejection {
        KindRejection()
    }

    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        if let failure { throw failure }
        log.didApply(changes.count)
    }

    func erase(_ cache: ModelContext) throws {
        if let failure { throw failure }
        log.didErase()
    }
}
