import Foundation

struct WeightRecordWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.weightRecord

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.WeightRecordPayload.self).syncedWeightRecord)
                .map { .weightRecord($0) }
        // サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
        case .deletion: UUID(uuidString: recordId).map { .weightRecordDeletion(recordId: $0) }
        case .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        if case .createWeightRecord(let writeId, let record) = write {
            return .init(
                recordId: record.id,
                body: .createWeightRecord(
                    .init(
                        id: writeId.canonicalString,
                        _type: .createWeightRecord,
                        weightRecord: .init(
                            id: record.id.canonicalString,
                            weightKg: record.weightKilograms,
                            measuredAt: record.measuredAt.millisecondsSince1970,
                            timeZone: record.timeZone.identifier,
                            imported: record.imported.map { imported in
                                .init(
                                    sourceAppName: imported.sourceAppName,
                                    sourceBundleId: imported.sourceBundleId,
                                    healthkitSampleUuid: imported.healthKitSampleId.canonicalString,
                                    bodyFat: imported.bodyFat.map { bodyFat in
                                        .init(
                                            percentage: bodyFat.percentage,
                                            healthkitSampleUuid: bodyFat.healthKitSampleId
                                                .canonicalString
                                        )
                                    }
                                )
                            }
                        )
                    )
                ))
        }
        if case .updateWeightRecord(let writeId, let correction) = write {
            return .init(
                recordId: correction.id,
                body: .updateWeightRecord(
                    .init(
                        id: writeId.canonicalString,
                        _type: .updateWeightRecord,
                        weightRecord: .init(
                            id: correction.id.canonicalString,
                            weightKg: correction.weightKilograms,
                            measuredAt: correction.measuredAt.millisecondsSince1970,
                            timeZone: correction.timeZone.identifier,
                            version: correction.version
                        )
                    )
                ))
        }
        if case .sourceDeletedWeightRecord(let writeId, let weightRecordId) = write {
            return .init(
                recordId: weightRecordId,
                body: .sourceDeletedWeightRecord(
                    .init(
                        id: writeId.canonicalString,
                        _type: .sourceDeletedWeightRecord,
                        weightRecordId: weightRecordId.canonicalString
                    )
                ))
        }
        return nil
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .weightRecord(let record) = change {
                return .value(id: record.id, record: SyncChange.WeightRecordPayload(record))
            }
            if case .weightRecordDeletion(let recordId) = change {
                return .deletion(id: recordId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            if case .createWeightRecord(let write) = wire {
                let record = write.weightRecord
                return .createWeightRecord(
                    writeId: try uuid(write.id),
                    record: NewWeightRecord(
                        id: try uuid(record.id),
                        weightKilograms: record.weightKg,
                        measuredAt: date(record.measuredAt),
                        timeZone: try knownTimeZone(record.timeZone),
                        imported: try record.imported.map { imported in
                            SyncedWeightRecord.Imported(
                                sourceAppName: imported.sourceAppName,
                                sourceBundleId: imported.sourceBundleId,
                                healthKitSampleId: try uuid(imported.healthkitSampleUuid),
                                bodyFat: try imported.bodyFat.map { bodyFat in
                                    .init(
                                        percentage: bodyFat.percentage,
                                        healthKitSampleId: try uuid(bodyFat.healthkitSampleUuid))
                                }
                            )
                        }
                    ))
            }
            if case .updateWeightRecord(let write) = wire {
                let record = write.weightRecord
                return .updateWeightRecord(
                    writeId: try uuid(write.id),
                    correction: WeightRecordCorrection(
                        id: try uuid(record.id),
                        weightKilograms: record.weightKg,
                        measuredAt: date(record.measuredAt),
                        timeZone: try knownTimeZone(record.timeZone),
                        version: record.version
                    ))
            }
            if case .sourceDeletedWeightRecord(let write) = wire {
                return .sourceDeletedWeightRecord(
                    writeId: try uuid(write.id), weightRecordId: try uuid(write.weightRecordId))
            }
            return nil
        }
    #endif
}

extension SyncChange {
    struct WeightRecordPayload: Decodable {
        let id: String
        let weightKg: Double
        let measuredAt: Int
        let timeZone: String
        let version: Int
        let imported: Imported?

        struct Imported: Decodable {
            let sourceAppName: String
            let sourceBundleId: String
            let healthkitSampleUuid: String
            let bodyFat: BodyFat?

            struct BodyFat: Decodable {
                let percentage: Double
                let healthkitSampleUuid: String
            }
        }

        var syncedWeightRecord: SyncedWeightRecord? {
            guard let id = UUID(uuidString: id), let timeZone = TimeZone(identifier: timeZone)
            else {
                return nil
            }
            var importedSource: SyncedWeightRecord.Imported?
            if let imported {
                guard let sampleId = UUID(uuidString: imported.healthkitSampleUuid) else {
                    return nil
                }
                var bodyFat: SyncedWeightRecord.Imported.BodyFat?
                if let payload = imported.bodyFat {
                    guard let bodyFatSampleId = UUID(uuidString: payload.healthkitSampleUuid) else {
                        return nil
                    }
                    bodyFat = .init(
                        percentage: payload.percentage, healthKitSampleId: bodyFatSampleId)
                }
                importedSource = .init(
                    sourceAppName: imported.sourceAppName,
                    sourceBundleId: imported.sourceBundleId,
                    healthKitSampleId: sampleId,
                    bodyFat: bodyFat
                )
            }
            return SyncedWeightRecord(
                id: id,
                weightKilograms: weightKg,
                measuredAt: Date(timeIntervalSince1970: Double(measuredAt) / 1000),
                timeZone: timeZone,
                version: version,
                imported: importedSource
            )
        }
    }
}

#if DEBUG
    extension SyncChange.WeightRecordPayload: Encodable {
        fileprivate init(_ record: SyncedWeightRecord) {
            self.init(
                id: record.id.canonicalString,
                weightKg: record.weightKilograms,
                measuredAt: record.measuredAt.millisecondsSince1970,
                timeZone: record.timeZone.identifier,
                version: record.version,
                imported: record.imported.map { imported in
                    Imported(
                        sourceAppName: imported.sourceAppName,
                        sourceBundleId: imported.sourceBundleId,
                        healthkitSampleUuid: imported.healthKitSampleId.canonicalString,
                        bodyFat: imported.bodyFat.map {
                            .init(
                                percentage: $0.percentage,
                                healthkitSampleUuid: $0.healthKitSampleId.canonicalString)
                        }
                    )
                }
            )
        }
    }
    extension SyncChange.WeightRecordPayload.Imported: Encodable {}
    extension SyncChange.WeightRecordPayload.Imported.BodyFat: Encodable {}
#endif
