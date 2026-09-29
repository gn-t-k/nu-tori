public import Foundation

/// ヘルスケアに書く、手で記録した体重1件。同じ同期 ID で書くと、版が大きいほうで置き換わる
public struct HealthWeightWrite: Sendable, Equatable {
    /// 体重記録の ID
    public let syncId: UUID
    /// 体重記録の版
    public let syncVersion: Int
    public let kilograms: Double
    public let instant: Date
    /// 時間帯のメタデータに付ける
    public let timeZone: TimeZone

    public init(
        syncId: UUID,
        syncVersion: Int,
        kilograms: Double,
        instant: Date,
        timeZone: TimeZone
    ) {
        self.syncId = syncId
        self.syncVersion = syncVersion
        self.kilograms = kilograms
        self.instant = instant
        self.timeZone = timeZone
    }
}
