public import Foundation

public struct SyncedWeightRecord: Sendable, Equatable {
    public let id: UUID
    public let weightKilograms: Double
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let version: Int
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
            public let percentage: Double
            public let healthKitSampleId: UUID

            public init(percentage: Double, healthKitSampleId: UUID) {
                self.percentage = percentage
                self.healthKitSampleId = healthKitSampleId
            }
        }
    }
}
