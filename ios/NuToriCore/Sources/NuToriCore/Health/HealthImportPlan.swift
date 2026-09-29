import Foundation

/// 読み取った分から、キャッシュに入れて送る記録と、消えたと送る記録の ID を決める
struct HealthImportPlan: Equatable {
    let newRecords: [WeightRecord]
    let deletedRecordIds: [UUID]

    /// - Parameters:
    ///   - deviceTimeZone: サンプルに時間帯のメタデータが無いときの、取り込んだときの端末のタイムゾーン
    ///   - readBoundary: 読み取りの期間の境界（iOS 27 のみ）
    ///   - cachedRecords: `affectedRecordIds(in:)` の ID のうち、キャッシュにある記録
    init(
        changes: HealthChanges,
        ownBundleId: String,
        deviceTimeZone: TimeZone,
        readBoundary: Date?,
        cachedRecords: [UUID: WeightRecord]
    ) {
        newRecords = Self.newRecords(
            in: changes,
            ownBundleId: ownBundleId,
            deviceTimeZone: deviceTimeZone,
            cachedRecords: cachedRecords
        )
        deletedRecordIds = Self.deletedRecordIds(
            in: changes,
            readBoundary: readBoundary,
            cachedRecords: cachedRecords
        )
    }

    /// 判断にキャッシュの記録が要る ID
    static func affectedRecordIds(in changes: HealthChanges) -> [UUID] {
        changes.weights.map { ImportedWeightRecordId.make(healthKitSampleId: $0.sampleId) }
            + changes.deletions.compactMap(\.weightSampleId).map {
                ImportedWeightRecordId.make(healthKitSampleId: $0)
            }
    }

    private static func newRecords(
        in changes: HealthChanges,
        ownBundleId: String,
        deviceTimeZone: TimeZone,
        cachedRecords: [UUID: WeightRecord]
    ) -> [WeightRecord] {
        var unpairedBodyFats = changes.bodyFats.filter { $0.sourceBundleId != ownBundleId }
        var seenRecordIds: Set<UUID> = []
        var records: [WeightRecord] = []
        for weight in changes.weights where weight.sourceBundleId != ownBundleId {
            guard AcceptedRange.weightKilograms.bounds.contains(weight.kilograms) else {
                continue
            }
            let recordId = ImportedWeightRecordId.make(healthKitSampleId: weight.sampleId)
            // 機種変更のあとの読み直しで、サーバーから取った直した値を上書きしない
            guard cachedRecords[recordId] == nil, seenRecordIds.insert(recordId).inserted else {
                continue
            }
            let pairedIndex = unpairedBodyFats.firstIndex {
                $0.sourceBundleId == weight.sourceBundleId && $0.instant == weight.instant
            }
            let pairedBodyFat = pairedIndex.map { unpairedBodyFats.remove(at: $0) }
            records.append(
                WeightRecord(
                    id: recordId,
                    kilograms: weight.kilograms,
                    instant: weight.instant,
                    timeZone: weight.timeZone ?? deviceTimeZone,
                    inputSource: .imported(
                        WeightRecord.ImportedSource(
                            appName: weight.sourceAppName,
                            bundleId: weight.sourceBundleId,
                            healthKitSampleId: weight.sampleId,
                            bodyFat: pairedBodyFat.flatMap(Self.importedBodyFat)
                        )
                    ),
                    version: 1
                )
            )
        }
        return records
    }

    private static func importedBodyFat(
        _ sample: HealthChanges.BodyFatSample
    ) -> WeightRecord.ImportedSource.BodyFat? {
        let percentage = sample.fraction * 100
        guard AcceptedRange.bodyFatPercentage.bounds.contains(percentage) else {
            return nil
        }
        return WeightRecord.ImportedSource.BodyFat(
            percentage: percentage,
            healthKitSampleId: sample.sampleId
        )
    }

    private static func deletedRecordIds(
        in changes: HealthChanges,
        readBoundary: Date?,
        cachedRecords: [UUID: WeightRecord]
    ) -> [UUID] {
        var seenRecordIds: Set<UUID> = []
        return changes.deletions.compactMap(\.weightSampleId).compactMap { sampleId in
            let recordId = ImportedWeightRecordId.make(healthKitSampleId: sampleId)
            // 境界より前が消えた分として返っても、ヘルスケアで消えたわけではない
            if let readBoundary, let cached = cachedRecords[recordId], cached.instant < readBoundary
            {
                return nil
            }
            return seenRecordIds.insert(recordId).inserted ? recordId : nil
        }
    }
}

extension HealthChanges.Deletion {
    fileprivate var weightSampleId: UUID? {
        switch self {
        case .weight(let sampleId): sampleId
        case .bodyFat: nil
        }
    }
}
