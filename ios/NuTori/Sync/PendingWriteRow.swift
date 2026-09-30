import Foundation
import NuToriCore
import SwiftData

typealias PendingWriteRow = PendingStoreSchemaV2.PendingWriteRow

extension PendingWriteRow {
    convenience init(entry: PendingEntry) {
        self.init(
            writeId: entry.writeId,
            enqueuedAt: entry.enqueuedAt,
            kind: entry.kind.rawValue,
            content: entry.content
        )
    }

    /// 体重記録・アカウントの設定の書き込み（`PendingWrite`）を、「種類の名前＋中身」にして持つ
    convenience init(write: PendingWrite) throws {
        self.init(entry: try write.entry())
    }

    /// 保存した文字列を `RecordKindName` に読む。読めない名前の行は、開くときに捨てる（`PendingStoreMigrationPlan.dropUnreadableRows`）ので、ここには来ない
    func entry() -> PendingEntry {
        guard let kindName = RecordKindName(rawValue: kind) else {
            preconditionFailure("読めない種類の名前の送り待ちは、開くときに捨てている: \(kind)")
        }
        return PendingEntry(
            writeId: writeId, enqueuedAt: enqueuedAt, kind: kindName, content: content)
    }
}
