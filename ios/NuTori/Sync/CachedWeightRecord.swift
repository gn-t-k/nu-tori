import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedWeightRecord {
    @Attribute(.unique) var recordId: UUID
    var kilograms: Double
    var measuredAt: Date
    var timeZoneIdentifier: String
    var version: Int
    /// 手で記録したものは無い。取り込みは、出どころが揃った JSON
    var importedJSON: Data?

    init(_ record: WeightRecord) throws {
        recordId = record.id
        kilograms = record.kilograms
        measuredAt = record.instant
        timeZoneIdentifier = record.timeZone.identifier
        version = record.version
        importedJSON = nil
        try apply(record)
    }

    func apply(_ record: WeightRecord) throws {
        kilograms = record.kilograms
        measuredAt = record.instant
        timeZoneIdentifier = record.timeZone.identifier
        version = record.version
        switch record.inputSource {
        case .manual:
            importedJSON = nil
        case .imported(let source):
            importedJSON = try JSONEncoder().encode(
                StoredWeightRecord.StoredImported(
                    appName: source.appName,
                    bundleId: source.bundleId,
                    healthKitSampleId: source.healthKitSampleId,
                    bodyFat: source.bodyFat.map {
                        StoredWeightRecord.StoredBodyFat(
                            percentage: $0.percentage, healthKitSampleId: $0.healthKitSampleId)
                    }
                )
            )
        }
    }

    func weightRecord() -> WeightRecord? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        let inputSource: WeightRecord.InputSource
        if let importedJSON {
            guard
                let imported = try? JSONDecoder().decode(
                    StoredWeightRecord.StoredImported.self, from: importedJSON)
            else { return nil }
            inputSource = .imported(
                .init(
                    appName: imported.appName,
                    bundleId: imported.bundleId,
                    healthKitSampleId: imported.healthKitSampleId,
                    bodyFat: imported.bodyFat.map {
                        .init(percentage: $0.percentage, healthKitSampleId: $0.healthKitSampleId)
                    }
                )
            )
        } else {
            inputSource = .manual
        }
        return WeightRecord(
            id: recordId,
            kilograms: kilograms,
            instant: measuredAt,
            timeZone: timeZone,
            inputSource: inputSource,
            version: version
        )
    }
}
