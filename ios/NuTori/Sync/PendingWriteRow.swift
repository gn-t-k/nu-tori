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

    /// 読めない名前の行は開くときに捨てる（`PendingStoreMigrationPlan.dropUnreadableRows`）。
    /// そのあとで読めない行があっても、ほかの送り待ちを送れるよう、その行だけ無いものとして読み飛ばす
    var entry: PendingEntry? {
        RecordKindName(rawValue: kind).map {
            PendingEntry(writeId: writeId, enqueuedAt: enqueuedAt, kind: $0, content: content)
        }
    }
}
