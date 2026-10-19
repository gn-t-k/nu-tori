import NuToriCore

extension GoalRecords {
    /// 渡さなかった記録は空のもの
    static func fixture(
        goals: [Goal] = [], dailyGuides: [DailyGuide] = [],
        expenditureEstimates: [ExpenditureEstimate] = [], weeklyReviews: [WeeklyReview] = [],
        weightTrend: WeightTrend? = nil, weightRecords: [WeightRecord] = []
    ) -> GoalRecords {
        GoalRecords(
            goals: goals, dailyGuides: dailyGuides, expenditureEstimates: expenditureEstimates,
            weeklyReviews: weeklyReviews, weightTrend: weightTrend, weightRecords: weightRecords)
    }
}
