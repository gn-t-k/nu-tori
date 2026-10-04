public import Foundation

/// 送り待ちの1件を、種類の中身（`Write`）の型で持つ。送り待ちの置き場には `entry()` の「種類の名前＋中身」で入る。
/// 送り待ちを作る口はここだけで、書き込みの ID は既定でここで振る
public struct Pending<Write: PendingWriteBody>: Sendable, Equatable {
    public let writeId: UUID
    public let enqueuedAt: Date
    public let write: Write

    public init(writeId: UUID = UUID(), enqueuedAt: Date, write: Write) {
        self.writeId = writeId
        self.enqueuedAt = enqueuedAt
        self.write = write
    }

    /// 送り待ちの中身を読む。読めなければ `PendingEntry.InvalidContentError`
    public init(entry: PendingEntry) throws {
        self.init(
            writeId: entry.writeId,
            enqueuedAt: entry.enqueuedAt,
            write: try Write(kind: entry.kind, content: entry.content)
        )
    }

    public func entry() throws -> PendingEntry {
        PendingEntry(
            writeId: writeId,
            enqueuedAt: enqueuedAt,
            kind: write.kindName,
            content: try write.content()
        )
    }
}
