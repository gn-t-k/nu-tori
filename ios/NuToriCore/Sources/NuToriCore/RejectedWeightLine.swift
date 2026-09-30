/// サーバーが受け付けなかった体重記録を、タイムラインに一時的に出す1行
public struct RejectedWeightLine: Hashable, Sendable {
    public let record: WeightRecord

    public init(_ rejected: RejectedWrite) {
        record = rejected.record
    }

    public var placement: Placement {
        record.version >= 2 ? .belowRecord : .insteadOfRecord
    }

    public var text: String {
        let kilograms = WeightAmountText.kilograms(record.kilograms)
        if record.version >= 2 {
            return "\(kilograms) に直せませんでした。"
        }
        let clock = WeightAmountText.clock(record.clockTime)
        return "\(clock) の体重 \(kilograms) は、記録できませんでした。"
    }

    public enum Placement: Equatable, Sendable {
        /// 新しい記録を消した位置
        case insteadOfRecord
        /// 直す前の値に戻した行のすぐ下
        case belowRecord
    }
}
