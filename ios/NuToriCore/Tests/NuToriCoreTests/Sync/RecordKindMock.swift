import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport

/// テスト用の登録簿の1行。当てられた変更の数を、メモリのキャッシュに数える。サーバーの `note` の変更（`SyncChange.unknown`）を持つ。
/// 種類の名前は、テストのために列挙へ case を足さず、本物の `accountSettings` を借りる（`RecordKindRegistry.ok(extra:)` は同じ名前の本物を替える）。
/// 送り待ちの中身は、消す体重記録の ID の文字列
struct RecordKindMock: RecordKind {
    struct Failure: Error, Equatable {}

    static let changeKind = "note"
    let failure: Failure?

    static func ok() -> RecordKindMock {
        RecordKindMock(failure: nil)
    }

    static func error(_ failure: Failure) -> RecordKindMock {
        RecordKindMock(failure: failure)
    }

    static func entry(recordId: UUID, writeId: UUID = UUID(), ageSeconds: TimeInterval = 0)
        -> PendingEntry
    {
        PendingEntry(
            writeId: writeId,
            enqueuedAt: SyncEngine.fixtureNow.addingTimeInterval(-ageSeconds),
            kind: .accountSettings,
            content: Data(recordId.uuidString.utf8)
        )
    }

    var synced: any SyncedRecordKind { Synced(failure: failure) }

    func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        if let failure { throw failure }
        cache.didApply(changes.count, forKind: name)
    }

    func erase(_ cache: RecordCacheMock) throws {
        if let failure { throw failure }
        cache.clearApplied(forKind: name)
    }

    /// キャッシュに依らない部分
    private struct Synced: SyncedRecordKind {
        let name = RecordKindName.accountSettings
        let failure: Failure?

        func owns(_ change: SyncChange) -> Bool {
            if case .unknown(let kind) = change { kind == RecordKindMock.changeKind } else { false }
        }

        func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
            if let failure { throw failure }
            let recordId = UUID(uuidString: String(decoding: entry.content, as: UTF8.self))!
            return .sourceDeletedWeightRecord(writeId: entry.writeId, weightRecordId: recordId)
        }

        func rejection(
            of entry: PendingEntry,
            reason: SyncWriteResult.RejectionReason,
            current: SyncWriteResult.Current?
        ) throws -> KindRejection {
            KindRejection.none
        }
    }
}
