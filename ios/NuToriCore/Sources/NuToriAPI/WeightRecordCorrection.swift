public import Foundation

/// 直す書き込みで送る体重記録の直したあとの値。取り込んだ記録の出どころは送らない
public struct WeightRecordCorrection: Sendable, Equatable {
    public let id: UUID
    public let weightKilograms: Double
    public let measuredAt: Date
    public let timeZone: TimeZone
    /// 直したあとの版。2 以上
    public let version: Int

    public init(
        id: UUID,
        weightKilograms: Double,
        measuredAt: Date,
        timeZone: TimeZone,
        version: Int
    ) {
        self.id = id
        self.weightKilograms = weightKilograms
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.version = version
    }
}
