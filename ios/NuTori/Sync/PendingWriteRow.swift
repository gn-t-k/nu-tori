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

    /// 読めない名前の行は開くときに捨てる（`PendingStoreMigrationPlan.dropUnreadableRows`）。
    /// そのあとで読めない行があっても、ほかの送り待ちを送れるよう、その行だけ無いものとして読み飛ばす
    var entry: PendingEntry? {
        RecordKindName(rawValue: kind).map {
            PendingEntry(writeId: writeId, enqueuedAt: enqueuedAt, kind: $0, content: content)
        }
    }
}
