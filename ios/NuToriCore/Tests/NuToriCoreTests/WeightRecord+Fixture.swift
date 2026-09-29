import Foundation
import NuToriCore
import Testing

extension WeightRecord {
    /// instant は ISO 8601 の時刻（"2026-09-24T07:12:00+09:00"）
    static func manual(
        _ kilograms: Double,
        at instant: String,
        in timeZoneIdentifier: String,
        id: UUID = UUID(),
        version: Int = 1
    ) throws -> WeightRecord {
        try WeightRecord(
            id: id,
            kilograms: kilograms,
            instant: Date(instant, strategy: .iso8601),
            timeZone: #require(TimeZone(identifier: timeZoneIdentifier)),
            inputSource: .manual,
            version: version
        )
    }

    static func imported(_ kilograms: Double, at instant: String, in timeZoneIdentifier: String)
        throws
        -> WeightRecord
    {
        try WeightRecord(
            id: UUID(),
            kilograms: kilograms,
            instant: Date(instant, strategy: .iso8601),
            timeZone: #require(TimeZone(identifier: timeZoneIdentifier)),
            inputSource: .imported(
                ImportedSource(
                    appName: "体重計アプリ",
                    bundleId: "com.example.scale",
                    healthKitSampleId: UUID(),
                    bodyFat: nil
                )
            ),
            version: 1
        )
    }
}
