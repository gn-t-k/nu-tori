public import Foundation

/// 作る書き込みで送る体重記録。版はサーバーが 1 にする
public struct NewWeightRecord: Sendable, Equatable {
    public let id: UUID
    public let weightKilograms: Double
    public let measuredAt: Date
    public let timeZone: TimeZone
    /// ヘルスケアから取り込んだ記録だけが持つ。nu-tori で手で記録したものは nil
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
