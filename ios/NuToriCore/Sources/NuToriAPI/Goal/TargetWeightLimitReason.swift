/// 自分で決める目標体重を受け付けない理由と、受け付ける幅の端を決めた理由
public enum TargetWeightLimitReason: Sendable, Equatable {
    /// ハード案の速さより速い
    case paceTooFast
    /// 1日の目安が下限 1,200 kcal を下回る
    case dailyGuideBelowMinimum
    /// 体重の傾向より向きの側に出ない
    case notOnDirectionSide
    /// 端末が知らない理由
    case unknown(String)

    /// サーバーの `rejectionReason`・`fastestEndReason` の値
    var serverName: String {
        switch self {
        case .paceTooFast: "pace_too_fast"
        case .dailyGuideBelowMinimum: "daily_guide_below_minimum"
        case .notOnDirectionSide: "not_on_direction_side"
        case .unknown(let name): name
        }
    }

    /// 知らない値は `unknown` にする
    init(serverName: String) {
        switch serverName {
        case "pace_too_fast": self = .paceTooFast
        case "daily_guide_below_minimum": self = .dailyGuideBelowMinimum
        case "not_on_direction_side": self = .notOnDirectionSide
        // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
        default: self = .unknown(serverName)
        }
    }
}
