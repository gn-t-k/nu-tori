/// ペース。今の体重の傾向の動きのままで期限に目標体重へ届くか（維持では、体重の傾向が目標体重の近くに収まっているか）。
/// 電波が無くても1日の丸・日のまとめ・体重の画面・週の振り返りで見せるため、同期で届いた体重の傾向から出す。
/// 手順と入力と期待値はサーバーの `computePace` と同じ（`docs/agents/shared-rules.md` の「ペース」）
public enum Pace: Hashable, Sendable {
    /// 間に合う。要るペースは週の振り返りの文だけが使う
    case onTrack(actualTenthsOfKilogramPerWeek: Int, requiredTenthsOfKilogramPerWeek: Int)
    /// 届かない
    case behind(
        shortfallTenthsOfKilogram: Int, actualTenthsOfKilogramPerWeek: Int,
        requiredTenthsOfKilogramPerWeek: Int)
    /// 言い切らない。直近 14 日に体重記録のある日が少ない
    case inconclusive(weightRecordDayCount: Int)
    /// まだ出ない。目標を立てて 14 日たっていない
    case pending
    /// 返さない。期限の日か達成した日を迎えた
    case unavailable
    /// 維持（期限後の維持を含む）。体重の傾向が目標体重の ±0.7 kg に収まっているか
    case maintenance(isWithinBand: Bool)

    /// 判定に要る日の体重の傾向がまだ届いていなければ nil
    /// - Parameters:
    ///   - judgedDay: 判定する日。週の振り返りではその週の日曜、ほかは今日
    ///   - achievedDay: 達成した日。達成していなければ nil
    ///   - weightRecordDays: 体重記録のある日
    public init?(
        judgedDay: CalendarDay, goal: Goal, achievedDay: CalendarDay?, weightTrend: WeightTrend?,
        weightRecordDays: [CalendarDay]
    ) {
        let days = weightTrend?.days ?? []
        let sign: Double
        let weightChange: Goal.WeightChange
        switch goal.direction {
        case .maintain:
            guard let trend = Self.trendKilograms(onOrBefore: judgedDay, in: days) else {
                return nil
            }
            // ちょうど幅の端にある傾向は、浮動小数の誤差で幅の外にしない
            self = .maintenance(
                isWithinBand: abs(trend - goal.targetWeightKilograms)
                    <= Self.maintenanceBandKilograms + Self.tolerance)
            return
        case .lose(let change):
            sign = -1
            weightChange = change
        case .gain(let change):
            sign = 1
            weightChange = change
        }
        if judgedDay >= weightChange.deadlineDay || achievedDay.map({ judgedDay >= $0 }) == true {
            self = .unavailable
            return
        }
        // 14 日前の体重の傾向が目標の中にあるよう、開始の日から 14 日たつまでは出さない
        if goal.startedDay.distance(to: judgedDay) < Self.windowDays {
            self = .pending
            return
        }
        // 判定する日とその前の 13 日
        let windowStart = judgedDay.advanced(by: -(Self.windowDays - 1))
        let recordDayCount = Set(weightRecordDays.filter { windowStart <= $0 && $0 <= judgedDay })
            .count
        if recordDayCount < Self.minimumWeightRecordDayCount {
            self = .inconclusive(weightRecordDayCount: recordDayCount)
            return
        }
        guard let judgedTrend = Self.trendKilograms(onOrBefore: judgedDay, in: days),
            let earlierTrend = Self.trendKilograms(
                onOrBefore: judgedDay.advanced(by: -Self.windowDays), in: days)
        else {
            return nil
        }
        let actualPerWeek = (judgedTrend - earlierTrend) / 2
        // 判定する日の翌日から期限の日までの週数
        let weeksToDeadline = Double(judgedDay.distance(to: weightChange.deadlineDay)) / 7
        let projected = judgedTrend + actualPerWeek * weeksToDeadline
        let actual = Self.roundedTenths(actualPerWeek)
        let required = Self.roundedTenths(
            (goal.targetWeightKilograms - judgedTrend) / weeksToDeadline)
        // 目標体重へ向かう側に、あとどれだけ足りないか。ちょうど目標体重に届く見込みは、浮動小数の誤差で届かないことにしない
        let shortfall = sign * (goal.targetWeightKilograms - projected)
        if shortfall <= Self.tolerance {
            self = .onTrack(
                actualTenthsOfKilogramPerWeek: actual, requiredTenthsOfKilogramPerWeek: required)
            return
        }
        // 0.1 kg に満たない不足を「0.0 kg 届かない」と言わないよう、切り上げる
        self = .behind(
            shortfallTenthsOfKilogram: Int((shortfall * 10 - Self.tolerance).rounded(.up)),
            actualTenthsOfKilogramPerWeek: actual, requiredTenthsOfKilogramPerWeek: required)
    }

    // 体重の傾向は最後の体重記録の日で終わるので、その日以前で最も新しい日の値を使う
    private static func trendKilograms(
        onOrBefore day: CalendarDay, in days: [WeightTrend.Day]
    ) -> Double? {
        days.last { $0.day <= day }?.kilograms
    }

    // サーバーの Math.round と同じく、ちょうど半分は大きい側へ丸める（-0.25 kg/週は -0.2）。
    // Swift の rounded() は 0 から遠い側へ丸めるので使わない
    private static func roundedTenths(_ kilograms: Double) -> Int {
        Int((kilograms * 10 + 0.5).rounded(.down))
    }

    /// 維持で、体重の傾向が収まっていればよい目標体重からの幅（±）。正本はサーバーの `computePace` の維持の幅
    static let maintenanceBandKilograms = 0.7

    private static let windowDays = 14

    private static let minimumWeightRecordDayCount = 4

    private static let tolerance = 1e-9
}
