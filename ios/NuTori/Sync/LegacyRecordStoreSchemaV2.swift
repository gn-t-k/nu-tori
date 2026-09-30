import Foundation
import SwiftData

/// 置き場を分ける前の、1つの置き場の形（版 2）。送り待ちとヘルスケアの同期の進み具合を読み出すためだけに固める。
/// 今の型を指さないので、キャッシュのモデルを変えても、ここは変えない
nonisolated enum LegacyRecordStoreSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            CachedWeightRecord.self, CachedPendingWrite.self, CachedSyncState.self,
            CachedAccountSettings.self, CachedHealthSyncState.self,
        ]
    }

    @Model
    nonisolated final class CachedWeightRecord {
        @Attribute(.unique) var recordId: UUID
        var kilograms: Double
        var measuredAt: Date
        var timeZoneIdentifier: String
        var version: Int
        var importedJSON: Data?

        init(
            recordId: UUID, kilograms: Double, measuredAt: Date, timeZoneIdentifier: String,
            version: Int, importedJSON: Data?
        ) {
            self.recordId = recordId
            self.kilograms = kilograms
            self.measuredAt = measuredAt
            self.timeZoneIdentifier = timeZoneIdentifier
            self.version = version
            self.importedJSON = importedJSON
        }
    }

    @Model
    nonisolated final class CachedPendingWrite {
        @Attribute(.unique) var writeId: UUID
        var enqueuedAt: Date
        var operationJSON: Data

        init(writeId: UUID, enqueuedAt: Date, operationJSON: Data) {
            self.writeId = writeId
            self.enqueuedAt = enqueuedAt
            self.operationJSON = operationJSON
        }
    }

    @Model
    nonisolated final class CachedSyncState {
        @Attribute(.unique) var singletonKey: String
        var afterSequence: Int
        var hasCompletedInitialPull: Bool
        var readableKindsVersion: Int
        var startedOn: String?

        init(
            singletonKey: String, afterSequence: Int, hasCompletedInitialPull: Bool,
            readableKindsVersion: Int, startedOn: String?
        ) {
            self.singletonKey = singletonKey
            self.afterSequence = afterSequence
            self.hasCompletedInitialPull = hasCompletedInitialPull
            self.readableKindsVersion = readableKindsVersion
            self.startedOn = startedOn
        }
    }

    @Model
    nonisolated final class CachedAccountSettings {
        @Attribute(.unique) var singletonKey: String
        var settingsId: UUID
        var sendsUsageData: Bool

        init(singletonKey: String, settingsId: UUID, sendsUsageData: Bool) {
            self.singletonKey = singletonKey
            self.settingsId = settingsId
            self.sendsUsageData = sendsUsageData
        }
    }

    @Model
    nonisolated final class CachedHealthSyncState {
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
