public import Foundation

/// サーバーと同期する体重記録
public struct SyncedWeightRecord: Sendable, Equatable {
    public let id: UUID
    public let weightKilograms: Double
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let version: Int
    /// ヘルスケアから取り込んだ記録だけが持つ。nu-tori で手で記録したものは nil
    public let imported: Imported?

    public init(
        id: UUID,
        weightKilograms: Double,
        measuredAt: Date,
        timeZone: TimeZone,
        version: Int,
        imported: Imported?
    ) {
        self.id = id
        self.weightKilograms = weightKilograms
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.version = version
        self.imported = imported
    }

    public struct Imported: Sendable, Equatable {
        public let sourceAppName: String
        public let sourceBundleId: String
        public let healthKitSampleId: UUID
        /// 体脂肪率を添えたときだけ
        public let bodyFat: BodyFat?

        public init(
            sourceAppName: String,
            sourceBundleId: String,
            healthKitSampleId: UUID,
            bodyFat: BodyFat?
        ) {
            self.sourceAppName = sourceAppName
            self.sourceBundleId = sourceBundleId
            self.healthKitSampleId = healthKitSampleId
            self.bodyFat = bodyFat
        }

        public struct BodyFat: Sendable, Equatable {
            /// % の値（25.0）
            public let percentage: Double
            public let healthKitSampleId: UUID

            public init(percentage: Double, healthKitSampleId: UUID) {
                self.percentage = percentage
                self.healthKitSampleId = healthKitSampleId
            }
        }
    }
}
