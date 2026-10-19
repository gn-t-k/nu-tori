/// 目標の画面に描くもの。今の目標、今の1日の目安、体重の傾向、推定消費カロリーと1日の目安の推移、週の振り返りへの1行、過去の目標。
/// キャッシュの記録から組む（電波が無くても、届いている記録のままに見せるため）
public struct GoalOverview: Hashable, Sendable {
    public let status: GoalStatus
    public let card: Card
    /// 今の1日の目安。まだ届いていなければ nil
    public let currentDailyGuide: DailyGuide?
    public let weightChart: WeightChart
    /// 期限より前に達成したとき・期限が来たときと、今の目標の1日の目安がまだ届いていないときは nil
    public let energyChart: EnergyChart?
    /// 週の振り返りへの1行で開く週の月曜。今の目標でいちばん新しく見直した週。まだ無ければ今週
    public let recapWeekMonday: CalendarDay
    /// 新しい順。0日の目標は除く。空なら見出しごと出さない
    public let pastGoals: [PastGoal]

    /// 目標がなければ nil（目標の画面を開かない）
    /// - Parameter today: 端末の今のタイムゾーンでの今日
    public init?(today: CalendarDay, records: GoalRecords) {
        guard
            let current = CurrentGoal(
                today: today, goals: records.goals, dailyGuides: records.dailyGuides)
        else { return nil }
        let goal = current.goal
        let status = GoalStatus(currentGoal: goal, goals: records.goals)
        guard let card = Card(status: status, today: today, records: records) else { return nil }
        self.status = status
        self.card = card
        currentDailyGuide = current.dailyGuide
        weightChart = WeightChart(status: status, goal: goal, today: today, records: records)
        energyChart = EnergyChart(status: status, today: today, records: records)
        // 見直す入力の週（当てる月曜の前の週）が今の目標に掛かる見直しだけ
        let latestReviewedMonday = records.weeklyReviews
            .map(\.effectiveDay)
            .filter { $0.advanced(by: -1) >= goal.startedDay && $0 <= today }
            .max()
        recapWeekMonday = latestReviewedMonday?.advanced(by: -7) ?? today.startOfWeek
        pastGoals = records.goals
            .filter { $0.id != goal.id }
            .sorted { ($0.startedDay, $0.decidedAt) > ($1.startedDay, $1.decidedAt) }
            .compactMap { PastGoal(goal: $0, records: records) }
    }
}
