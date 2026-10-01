public import Foundation
public import NuToriAPI

/// 体重記録の同期の形。記録の種類の入口のうち、キャッシュの型に依らない部分。
/// 取りに行った変更の見分け方と今の値の読み方、送り待ちから送る書き込みを作る
public struct WeightRecordSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った体重記録が読めなくなる
    public static let kindName = RecordKindName.weightRecord

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値と、消す記録の ID
    public struct Current: Sendable, Equatable {
        public let records: [WeightRecord]
        public let removedRecordIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        switch change {
        case .weightRecord, .weightRecordDeletion: true
        case .accountSettings, .dish, .dishDeletion, .ingredient,
            .ingredientDeletion, .meal, .mealDeletion, .mealEstimationStatus,
            .mealEstimationStatusDeletion, .unknown:
            false
        }
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let write = try PendingWrite(entry: entry)
        switch write.operation {
        case .createWeightRecord(let record):
            return .createWeightRecord(writeId: write.writeId, record: NewWeightRecord(record))
        case .correctWeightRecord(let record):
            return .updateWeightRecord(
                writeId: write.writeId, correction: WeightRecordCorrection(record))
        case .sourceDeletedWeightRecord(let recordId):
            return .sourceDeletedWeightRecord(writeId: write.writeId, weightRecordId: recordId)
        case .updateAccountSettings:
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
    }

    /// 受け付けなかった作る・直す書き込みは、画面に出す行にする。記録の値と削除の印は、サーバーの今の値を同期の働きが当てる。
    /// サーバーに記録が無いときは、端末にだけあった記録を外す。元のサンプルが消えた書き込みは、戻す記録も出す記録も無い
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?
    ) throws -> KindRejection {
        let write = try PendingWrite(entry: entry)
        let serverHasValue: Bool
        if case .value = current { serverHasValue = true } else { serverHasValue = false }
        switch write.operation {
        case .createWeightRecord(let record), .correctWeightRecord(let record):
            return KindRejection(
                rejectedWrite: RejectedWrite(
                    writeId: write.writeId, reason: reason,
                    record: .weightRecord(record, serverHasValue: serverHasValue)),
                removingChanges: [.weightRecordDeletion(recordId: record.id)]
            )
        case .sourceDeletedWeightRecord:
            // 消すかどうかを決めるのはサーバーで、送り直さない
            return KindRejection.none
        case .updateAccountSettings:
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
    }

    /// 記録を作った・直したときの結果。送り待ちに足し、今の値を、取りに行った変更と同じ形でキャッシュに当てる
    public func saving(_ record: WeightRecord, enqueuing write: PendingWrite) throws
        -> SyncBoxResult
    {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [
                KindChanges(kind: name, changes: [.weightRecord(SyncedWeightRecord(record))])
            ]
        )
    }

    /// 取りに行った変更を、今の値の並びにする。削除の印は、置き場に無い ID でも読み飛ばせるよう ID だけを返す
    public func current(from changes: [SyncChange]) -> Current {
        var records: [WeightRecord] = []
        var removedRecordIds: [UUID] = []
        for change in changes {
            switch change {
            case .weightRecord(let record): records.append(WeightRecord(record))
            case .weightRecordDeletion(let recordId): removedRecordIds.append(recordId)
            case .accountSettings, .dish, .dishDeletion, .ingredient,
                .ingredientDeletion, .meal, .mealDeletion, .mealEstimationStatus,
                .mealEstimationStatusDeletion, .unknown:
                break
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

extension SyncedWeightRecord {
    init(_ record: WeightRecord) {
        let new = NewWeightRecord(record)
        self.init(
            id: record.id,
            weightKilograms: record.kilograms,
            measuredAt: record.instant,
            timeZone: record.timeZone,
            version: record.version,
            imported: new.imported
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
