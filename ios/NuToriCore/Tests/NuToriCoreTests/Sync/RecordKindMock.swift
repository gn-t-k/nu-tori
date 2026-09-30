import Foundation
import NuToriAPI
import NuToriCore

/// 種類の名前が `note` の、テスト用の登録簿の1行。サーバーの `note` の変更（`SyncChange.unknown`）を持つ。
/// 送り待ちの中身は、消す体重記録の ID の文字列
struct RecordKindMock: RecordKind {
    struct Failure: Error, Equatable {}

    let name = "note"
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
            kind: "note",
            content: Data(recordId.uuidString.utf8)
        )
    }

    func owns(_ change: SyncChange) -> Bool {
        if case .unknown(let kind) = change { kind == name } else { false }
    }

    func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        if let failure { throw failure }
        let recordId = UUID(uuidString: String(decoding: entry.content, as: UTF8.self))!
        return .sourceDeletedWeightRecord(writeId: entry.writeId, weightRecordId: recordId)
    }

    func apply(_ changes: [SyncChange], to cache: NoteCache) throws {
        if let failure { throw failure }
        cache.didApply(changes.count)
    }

    func erase(_ cache: NoteCache) throws {
        if let failure { throw failure }
        cache.clear()
    }
}
