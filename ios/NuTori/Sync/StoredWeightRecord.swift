import Foundation
import NuToriCore

/// 送り待ちに、記録の写しを JSON で持たせる。キャッシュの行を消しても、戻す値が残る
nonisolated struct StoredWeightRecord: Codable {
    var id: UUID
    var kilograms: Double
    var measuredAt: Date
    var timeZoneIdentifier: String
    var version: Int
    var imported: StoredImported?

    struct StoredImported: Codable {
        var appName: String
        var bundleId: String
        var healthKitSampleId: UUID
        var bodyFat: StoredBodyFat?
    }

    struct StoredBodyFat: Codable {
        var percentage: Double
        var healthKitSampleId: UUID
    }

    init(_ record: WeightRecord) {
        id = record.id
        kilograms = record.kilograms
        measuredAt = record.instant
        timeZoneIdentifier = record.timeZone.identifier
        version = record.version
        switch record.inputSource {
        case .manual:
            imported = nil
        case .imported(let source):
            imported = StoredImported(
                appName: source.appName,
                bundleId: source.bundleId,
                healthKitSampleId: source.healthKitSampleId,
                bodyFat: source.bodyFat.map {
                    StoredBodyFat(
                        percentage: $0.percentage, healthKitSampleId: $0.healthKitSampleId)
                }
            )
        }
    }

    func weightRecord() throws -> WeightRecord {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw RecordStoreError.invalidTimeZone(timeZoneIdentifier)
        }
        let inputSource: WeightRecord.InputSource =
            if let imported {
                .imported(
                    WeightRecord.ImportedSource(
                        appName: imported.appName,
                        bundleId: imported.bundleId,
                        healthKitSampleId: imported.healthKitSampleId,
                        bodyFat: imported.bodyFat.map {
                            .init(
                                percentage: $0.percentage, healthKitSampleId: $0.healthKitSampleId)
                        }
                    )
                )
            } else {
                .manual
            }
        return WeightRecord(
            id: id,
            kilograms: kilograms,
            instant: measuredAt,
            timeZone: timeZone,
            inputSource: inputSource,
            version: version
        )
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(_ data: Data) throws -> StoredWeightRecord {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

enum RecordStoreError: Error {
    case invalidTimeZone(String)
    case missingPrevious
    case unknownPendingWriteKind(String)
}
