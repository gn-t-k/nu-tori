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
    /// 手で記録したものは、出どころの3つとも無い
    var sourceAppName: String?
    var sourceBundleId: String?
    var healthKitSampleId: UUID?
    /// 体脂肪率を添えた取り込みだけ、割合とサンプルの ID を両方持つ
    var bodyFatPercentage: Double?
    var bodyFatSampleId: UUID?

    init(_ record: WeightRecord) {
        recordId = record.id
        kilograms = record.kilograms
        measuredAt = record.instant
        timeZoneIdentifier = record.timeZone.identifier
        version = record.version
        sourceAppName = nil
        sourceBundleId = nil
        healthKitSampleId = nil
        bodyFatPercentage = nil
        bodyFatSampleId = nil
        apply(record)
    }

    func apply(_ record: WeightRecord) {
        kilograms = record.kilograms
        measuredAt = record.instant
        timeZoneIdentifier = record.timeZone.identifier
        version = record.version
        switch record.inputSource {
        case .manual:
            sourceAppName = nil
            sourceBundleId = nil
            healthKitSampleId = nil
            bodyFatPercentage = nil
            bodyFatSampleId = nil
        case .imported(let source):
            sourceAppName = source.appName
            sourceBundleId = source.bundleId
            healthKitSampleId = source.healthKitSampleId
            bodyFatPercentage = source.bodyFat?.percentage
            bodyFatSampleId = source.bodyFat?.healthKitSampleId
        }
    }

    func weightRecord() -> WeightRecord? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        let inputSource: WeightRecord.InputSource
        if let sourceAppName, let sourceBundleId, let healthKitSampleId {
            let bodyFat: WeightRecord.ImportedSource.BodyFat?
            switch (bodyFatPercentage, bodyFatSampleId) {
            case (nil, nil):
                bodyFat = nil
            case (let percentage?, let sampleId?):
                bodyFat = .init(percentage: percentage, healthKitSampleId: sampleId)
            case (_, _):
                return nil
            }
            inputSource = .imported(
                .init(
                    appName: sourceAppName,
                    bundleId: sourceBundleId,
                    healthKitSampleId: healthKitSampleId,
                    bodyFat: bodyFat
                )
            )
        } else if sourceAppName != nil || sourceBundleId != nil || healthKitSampleId != nil {
            return nil
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
