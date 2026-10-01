/// サーバーが受け付けなかった体重記録を、タイムラインに一時的に出す1行
public struct RejectedWeightLine: Hashable, Sendable {
    public let record: WeightRecord
    /// サーバーにその記録の値があるか。位置は、これで決める
    public let serverHasValue: Bool

    public init(record: WeightRecord, serverHasValue: Bool) {
        self.record = record
        self.serverHasValue = serverHasValue
    }

    public var placement: Placement {
        serverHasValue ? .belowRecord : .insteadOfRecord
    }

    public var text: String {
        let kilograms = WeightAmountText.kilograms(record.kilograms)
        if serverHasValue {
            return "\(kilograms) に直せませんでした。"
        }
        let clock = WeightAmountText.clock(record.clockTime)
        return "\(clock) の体重 \(kilograms) は、記録できませんでした。"
    }

    public enum Placement: Equatable, Sendable {
        /// サーバーに値が無いので、記録を外した位置（作った記録の時刻）
        case insteadOfRecord
        /// サーバーの値に戻した記録のすぐ下
        case belowRecord
    }
}
