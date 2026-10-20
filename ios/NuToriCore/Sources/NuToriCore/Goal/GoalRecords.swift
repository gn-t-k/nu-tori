/// 目標の経過を描くもとの、キャッシュの記録。週の振り返りと目標の画面が読む
public struct GoalRecords: Sendable {
    /// 閉じた目標も含む
    public let goals: [Goal]
    /// 目標がまだ届いていない1日の目安も含む
    public let dailyGuides: [DailyGuide]
    public let expenditureEstimates: [ExpenditureEstimate]
    /// 見送った週も含む
    public let weeklyReviews: [WeeklyReview]
    /// 体重記録が1つも無ければ nil
    public let weightTrend: WeightTrend?
    /// 送り待ちを含む
    public let weightRecords: [WeightRecord]

    public init(
        goals: [Goal], dailyGuides: [DailyGuide], expenditureEstimates: [ExpenditureEstimate],
        weeklyReviews: [WeeklyReview], weightTrend: WeightTrend?, weightRecords: [WeightRecord]
    ) {
        self.goals = goals
        self.dailyGuides = dailyGuides
        self.expenditureEstimates = expenditureEstimates
        self.weeklyReviews = weeklyReviews
        self.weightTrend = weightTrend
        self.weightRecords = weightRecords
    }

    /// その日以前で最も新しい体重の傾向。体重の傾向は最後の体重記録の日で終わるため
    func trendKilograms(onOrBefore day: CalendarDay) -> Double? {
        weightTrend?.days.last { $0.day <= day }?.kilograms
    }
}
