public import Foundation

/// 今の道の送り待ち（`PendingWrite`）と、「種類の名前＋中身」の相互変換。
/// 中身は、送り待ちの置き場の版 1 の JSON と同じ形。直す前の値（`previous`）は #185 まで中身に残す
extension PendingWrite {
    public struct InvalidEntryError: Error, Equatable {
        public let kind: String

        public init(kind: String) {
            self.kind = kind
        }
    }

    public init(entry: PendingEntry) throws {
        let content: PendingWriteContent
        do {
            content = try JSONDecoder().decode(PendingWriteContent.self, from: entry.content)
        } catch {
            throw InvalidEntryError(kind: entry.kind)
        }
        self.init(
            writeId: entry.writeId,
            enqueuedAt: entry.enqueuedAt,
            operation: try content.operation(kind: entry.kind)
        )
    }

    public func entry() throws -> PendingEntry {
        let stored = PendingWriteContent(operation)
        return PendingEntry(
            writeId: writeId,
            enqueuedAt: enqueuedAt,
            kind: stored.kindName,
            content: try JSONEncoder().encode(stored)
        )
    }

    /// 版 1 の中身（種類の名前を持たない）から、種類の名前を読む。読めなければ nil
    public static func kindName(ofVersion1Content content: Data) -> String? {
        try? JSONDecoder().decode(PendingWriteContent.self, from: content).kindName
    }
}
