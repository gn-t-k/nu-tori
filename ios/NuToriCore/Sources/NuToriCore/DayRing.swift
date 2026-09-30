/// 1日の丸の帯に出す、その日の丸。食べた量などは、種類を足すときに欄を足す
public struct DayRing: Hashable, Sendable {
    public let hasWeightRecord: Bool

    public init(hasWeightRecord: Bool) {
        self.hasWeightRecord = hasWeightRecord
    }
}
