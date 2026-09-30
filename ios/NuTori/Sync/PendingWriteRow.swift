import Foundation
import NuToriCore
import SwiftData

typealias PendingWriteRow = PendingStoreSchemaV2.PendingWriteRow

extension PendingWriteRow {
    convenience init(entry: PendingEntry) {
        self.init(
            writeId: entry.writeId,
            enqueuedAt: entry.enqueuedAt,
            kind: entry.kind,
            content: entry.content
        )
    }

    /// 体重記録・アカウントの設定の書き込み（`PendingWrite`）を、「種類の名前＋中身」にして持つ
    convenience init(write: PendingWrite) throws {
        self.init(entry: try write.entry())
    }

    func entry() -> PendingEntry {
        PendingEntry(writeId: writeId, enqueuedAt: enqueuedAt, kind: kind, content: content)
    }
}
