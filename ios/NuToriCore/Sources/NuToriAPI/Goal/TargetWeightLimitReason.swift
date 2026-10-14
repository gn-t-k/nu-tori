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
}
