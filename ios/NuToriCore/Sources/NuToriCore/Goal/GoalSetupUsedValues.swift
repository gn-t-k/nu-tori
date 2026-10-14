public import NuToriAPI

/// 目標案の計算に使った値。目標案の上の1行に出す
public enum GoalSetupUsedValues: Equatable, Sendable {
    /// 初めての目標で、最近4週の記録から逆算した推定消費カロリー
    case backCalculated(expenditureKilocalories: Int)
    /// 初めての目標で逆算できず、足りない値の「次へ」で決めた身体データから式で出した。体重は計算に使った開始の日の体重の傾向
    case formula(GoalSetupBody, weightKilograms: Double)
    /// 立て直しの、今の推定消費カロリー
    case current(expenditureKilocalories: Int)
}
