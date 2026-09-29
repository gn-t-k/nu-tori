public import Foundation

/// 版は持たない。サーバーが 1 にする
public struct NewWeightRecord: Sendable, Equatable {
    public let id: UUID
    public let weightKilograms: Double
    public let measuredAt: Date
    public let timeZone: TimeZone
    public let imported: SyncedWeightRecord.Imported?

    public init(
        id: UUID,
        weightKilograms: Double,
        measuredAt: Date,
        timeZone: TimeZone,
        imported: SyncedWeightRecord.Imported?
    ) {
        self.id = id
        self.weightKilograms = weightKilograms
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.imported = imported
    }
}
