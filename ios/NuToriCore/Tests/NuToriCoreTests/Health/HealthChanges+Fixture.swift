import Foundation
import NuToriCore
import Testing

extension HealthChanges {
    static let fixtureAnchor = HealthAnchor(data: Data("anchor-2".utf8))

    static func fixture(
        weights: [WeightSample] = [],
        bodyFats: [BodyFatSample] = [],
        deletions: [Deletion] = []
    ) -> HealthChanges {
        HealthChanges(
            weights: weights,
            bodyFats: bodyFats,
            deletions: deletions,
            anchor: fixtureAnchor
        )
    }
}

extension HealthChanges.WeightSample {
    /// instant は ISO 8601 の時刻（"2026-09-24T07:12:00+09:00"）。timeZoneIdentifier が nil なら、時間帯のメタデータ無し
    static func fixture(
        sampleId: String,
        kilograms: Double = 70.0,
        at instant: String = "2026-09-24T07:12:00+09:00",
        timeZoneIdentifier: String? = "Asia/Tokyo",
        sourceBundleId: String = "com.example.scale"
    ) throws -> HealthChanges.WeightSample {
        try HealthChanges.WeightSample(
            sampleId: #require(UUID(uuidString: sampleId)),
            kilograms: kilograms,
            instant: Date(instant, strategy: .iso8601),
            sourceAppName: "体重計アプリ",
            sourceBundleId: sourceBundleId,
            timeZone: timeZoneIdentifier.map { try #require(TimeZone(identifier: $0)) }
        )
    }
}

extension HealthChanges.BodyFatSample {
    static func fixture(
        sampleId: String,
        fraction: Double = 0.25,
        at instant: String = "2026-09-24T07:12:00+09:00",
        sourceBundleId: String = "com.example.scale"
    ) throws -> HealthChanges.BodyFatSample {
        try HealthChanges.BodyFatSample(
            sampleId: #require(UUID(uuidString: sampleId)),
            fraction: fraction,
            instant: Date(instant, strategy: .iso8601),
            sourceBundleId: sourceBundleId
        )
    }
}
