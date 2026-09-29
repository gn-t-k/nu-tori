/// サーバーが受け付けなかった体重記録を、タイムラインに一時的に出す1行
public struct RejectedWeightLine: Equatable, Sendable {
    public let record: WeightRecord
    public let text: String
    public let placement: Placement

    public init(_ rejected: RejectedWrite) {
        record = rejected.record
        if rejected.record.version >= 2 {
            placement = .belowRecord
            text = "\(WeightAmountText.kilograms(rejected.record.kilograms)) に直せませんでした。"
        } else {
            placement = .insteadOfRecord
            let clock = WeightAmountText.clock(rejected.record.clockTime)
            let kilograms = WeightAmountText.kilograms(rejected.record.kilograms)
            text = "\(clock) の体重 \(kilograms) は、記録できませんでした。"
        }
    }

    public enum Placement: Equatable, Sendable {
        /// 新しい記録を消した位置
        case insteadOfRecord
        /// 直す前の値に戻した行のすぐ下
        case belowRecord
    }
}
