public import Foundation
public import NuToriAPI

/// 体重記録の同期の形。記録の種類の入口のうち、キャッシュの型に依らない部分。
/// 取りに行った変更の見分け方と今の値の読み方、送り待ちから送る書き込みを作る
public struct WeightRecordSyncing: SyncedRecordKind {
    public var name: String { SyncEngine.weightRecordKind }

    /// 取りに行った変更のうち、当てる今の値と、消す記録の ID
    public struct Current: Sendable, Equatable {
        public let records: [WeightRecord]
        public let removedRecordIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        switch change {
        case .weightRecord, .weightRecordDeletion: true
        case .accountSettings, .unknown: false
        }
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let write = try PendingWrite(entry: entry)
        switch write.operation {
        case .createWeightRecord(let record):
            return .createWeightRecord(writeId: write.writeId, record: NewWeightRecord(record))
        case .correctWeightRecord(let record, previous: _):
            return .updateWeightRecord(
                writeId: write.writeId, correction: WeightRecordCorrection(record))
        case .sourceDeletedWeightRecord(let recordId):
            return .sourceDeletedWeightRecord(writeId: write.writeId, weightRecordId: recordId)
        case .updateAccountSettings:
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
    }

    /// 取りに行った変更を、今の値の並びにする。削除の印は、置き場に無い ID でも読み飛ばせるよう ID だけを返す
    public func current(from changes: [SyncChange]) -> Current {
        var records: [WeightRecord] = []
        var removedRecordIds: [UUID] = []
        for change in changes {
            switch change {
            case .weightRecord(let record): records.append(WeightRecord(record))
            case .weightRecordDeletion(let recordId): removedRecordIds.append(recordId)
            case .accountSettings, .unknown: break
            }
        }
        return Current(records: records, removedRecordIds: removedRecordIds)
    }
}

extension NewWeightRecord {
    init(_ record: WeightRecord) {
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            imported: record.inputSource.importedSource.map { source in
                SyncedWeightRecord.Imported(
                    sourceAppName: source.appName,
                    sourceBundleId: source.bundleId,
                    healthKitSampleId: source.healthKitSampleId,
                    bodyFat: source.bodyFat.map {
                        SyncedWeightRecord.Imported.BodyFat(
                            percentage: $0.percentage,
                            healthKitSampleId: $0.healthKitSampleId
                        )
                    }
                )
            }
        )
    }
}

extension WeightRecordCorrection {
    init(_ record: WeightRecord) {
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            version: record.version
        )
    }
}

extension WeightRecord {
    init(_ record: SyncedWeightRecord) {
        self.init(
            id: record.id,
            kilograms: record.weightKilograms,
            instant: record.measuredAt,
            timeZone: record.timeZone,
            inputSource: record.imported.map { imported in
                .imported(
                    ImportedSource(
                        appName: imported.sourceAppName,
                        bundleId: imported.sourceBundleId,
                        healthKitSampleId: imported.healthKitSampleId,
                        bodyFat: imported.bodyFat.map {
                            ImportedSource.BodyFat(
                                percentage: $0.percentage,
                                healthKitSampleId: $0.healthKitSampleId
                            )
                        }
                    )
                )
            } ?? .manual,
            version: record.version
        )
    }
}

extension WeightRecord.InputSource {
    var importedSource: WeightRecord.ImportedSource? {
        switch self {
        case .manual: nil
        case .imported(let source): source
        }
    }
}
