import Foundation
import SwiftData

/// 送り待ちの置き場の、この版のモデルの写し（ADR-0022）。今の型を指さない。
/// 送り待ちを「種類の名前＋中身」で持つ。種類を足しても、この形は変えない。
/// 形を変えるときは、この版を固めたまま `PendingStoreSchemaV3` を足し、`PendingStoreMigrationPlan` に段を足す
nonisolated enum PendingStoreSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [PendingWriteRow.self, HealthSyncStateRow.self]
    }

    @Model
    nonisolated final class PendingWriteRow {
        @Attribute(.unique) var writeId: UUID
        var enqueuedAt: Date
        /// 記録の種類の名前。版 1 から移すときは、中身から読んで書く
        var kind: String = ""
        /// 種類が決める書き込みの中身。記録の行を消しても、送る値が残る。版 1 の `operationJSON`
        @Attribute(originalName: "operationJSON") var content: Data

        init(writeId: UUID, enqueuedAt: Date, kind: String, content: Data) {
            self.writeId = writeId
            self.enqueuedAt = enqueuedAt
            self.kind = kind
            self.content = content
        }
    }

    @Model
    nonisolated final class HealthSyncStateRow {
        @Attribute(.unique) var singletonKey: String
        var anchorData: Data?
        var hasWrittenCachedManualRecords: Bool

        init(singletonKey: String, anchorData: Data?, hasWrittenCachedManualRecords: Bool) {
            self.singletonKey = singletonKey
            self.anchorData = anchorData
            self.hasWrittenCachedManualRecords = hasWrittenCachedManualRecords
        }
    }
}
