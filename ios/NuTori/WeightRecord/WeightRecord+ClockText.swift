import NuToriCore

extension WeightRecord {
    /// タイムラインの体重の行の外に置く時刻と、その行の読み上げに使う時刻
    var clockText: String {
        WeightAmountText.clock(clockTime)
    }
}
