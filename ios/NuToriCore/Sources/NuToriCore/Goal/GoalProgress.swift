/// 日のまとめに出す、進行中の目標の要約。減量・増量は「あと 2.3 kg・あと 45 日」、維持は「65.0 kg を保つ」。
/// 間に合うペースかは、ここでは出さない（次の仕様）
public enum GoalProgress: Hashable, Sendable {
    /// 減量・増量
    case weightChange(remainingTenthsOfKilogram: Int, remainingDays: Int)
    /// 維持
    case maintain(targetKilograms: Double)

    /// 減量・増量で、今日以前の体重の傾向が無ければ nil
    /// - Parameters:
    ///   - goal: 今日を含む目標（`DailyGuideForDay(on: today, …)?.goal`）
    ///   - today: 端末の今のタイムゾーンでの今日
    public init?(goal: Goal, today: CalendarDay, weightTrend: WeightTrend?) {
        let weightChange: Goal.WeightChange
        let towardTarget: Double
        // 体重の傾向は最後の体重記録の日で終わるので、今日以前で最も新しい日の値を今日の傾向にする
        // （サーバーの開始の日の体重の傾向 `findStartingWeightTrend` と同じ選び方）
        let trend = weightTrend?.days.last { $0.day <= today }?.kilograms
        switch goal.direction {
        case .maintain:
            self = .maintain(targetKilograms: goal.targetWeightKilograms)
            return
        case .lose(let change):
            guard let trend else { return nil }
            weightChange = change
            towardTarget = trend - goal.targetWeightKilograms
        case .gain(let change):
            guard let trend else { return nil }
            weightChange = change
            towardTarget = goal.targetWeightKilograms - trend
        }
        // 目標体重を越えたら 0 で止める。越えた分は、間に合うペースか（次の仕様）で伝える
        self = .weightChange(
            remainingTenthsOfKilogram: max(Int((towardTarget * 10).rounded()), 0),
            // 両端を含めて数える（期限の日 − 今日 + 1）。期限を過ぎたら 0 で止める
            remainingDays: max(today.distance(to: weightChange.deadlineDay) + 1, 0))
    }

    /// 今日を含む目標（`DailyGuideForDay`）の要約。今日を含む目標が無ければ nil
    /// - Parameters:
    ///   - goals: 閉じた目標も含む
    ///   - dailyGuides: 目標がまだ届いていない1日の目安も含む
    public init?(
        today: CalendarDay, goals: [Goal], dailyGuides: [DailyGuide], weightTrend: WeightTrend?
    ) {
        guard let found = DailyGuideForDay(on: today, goals: goals, dailyGuides: dailyGuides)
        else { return nil }
        self.init(goal: found.goal, today: today, weightTrend: weightTrend)
    }

    public var text: String {
        switch self {
        case .weightChange(let tenths, let days):
            "あと \(tenths / 10).\(tenths % 10) kg・あと \(days) 日"
        case .maintain(let kilograms):
            "\(WeightAmountText.kilograms(kilograms)) を保つ"
        }
    }
}
