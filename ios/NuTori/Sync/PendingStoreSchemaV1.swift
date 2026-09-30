import Foundation
import SwiftData

/// 送り待ちの置き場の、この版のモデルの写し（ADR-0022）。今の型を指さない。
/// 形を変えるときは、この版を固めたまま `PendingStoreSchemaV2` を足し、`PendingStoreMigrationPlan` に段を足す
nonisolated enum PendingStoreSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [PendingWriteRow.self, HealthSyncStateRow.self]
    }

    @Model
    nonisolated final class PendingWriteRow {
        @Attribute(.unique) var writeId: UUID
        var enqueuedAt: Date
        /// 書き込みの中身。記録の行を消しても、送る値が残る
        var operationJSON: Data

        init(writeId: UUID, enqueuedAt: Date, operationJSON: Data) {
            self.writeId = writeId
            self.enqueuedAt = enqueuedAt
            self.operationJSON = operationJSON
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
