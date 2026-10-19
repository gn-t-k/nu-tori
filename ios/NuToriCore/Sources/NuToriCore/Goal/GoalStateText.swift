/// 日のまとめと体重の画面が、達成・期限・維持の目標に書く1行
enum GoalStateText {
    /// 「70.0 kg を達成しました」
    static func achieved(_ goal: Goal) -> String {
        "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を達成しました"
    }

    /// 「期限を迎えました・あと 0.4 kg」。期限のあとに達成していたら「12月3日に 70.0 kg を達成しました」
    static func deadlineReached(_ goal: Goal, records: GoalRecords) -> String {
        if let achievement = goal.achievement {
            return "\(GoalText.monthDay(achievement.achievedDay))に \(achieved(goal))"
        }
        guard let result = DeadlineResult(goal: goal, records: records) else {
            return "期限を迎えました"
        }
        return "期限を迎えました・あと \(GoalText.kilograms(tenths: result.remainingTenthsOfKilogram))"
    }

    /// 「72.0 kg を保つ」
    static func keeping(_ goal: Goal) -> String {
        "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を保つ"
    }

    /// 「72.0 kg を保つ・保てています」。体重の傾向がまだ無ければ「72.0 kg を保つ」
    static func keepingWithBand(_ goal: Goal, day: CalendarDay, records: GoalRecords) -> String {
        guard let isWithinBand = isWithinBand(goal, day: day, records: records) else {
            return keeping(goal)
        }
        return "\(keeping(goal))・\(isWithinBand ? "保てています" : "幅から外れています")"
    }

    /// 体重の傾向が保つ幅に入っているか。体重の傾向がまだ無ければ nil
    static func isWithinBand(_ goal: Goal, day: CalendarDay, records: GoalRecords) -> Bool? {
        guard
            case .maintenance(let isWithinBand) = Pace(
                judgedDay: day, goal: goal, achievedDay: nil, weightTrend: records.weightTrend,
                weightRecordDays: records.weightRecords.map(\.day))
        else { return nil }
        return isWithinBand
    }

    /// その日のペース。判定に要る体重の傾向がまだ届いていなければ nil
    static func pace(_ goal: Goal, day: CalendarDay, records: GoalRecords) -> Pace? {
        Pace(
            judgedDay: day, goal: goal, achievedDay: goal.achievement?.achievedDay,
            weightTrend: records.weightTrend, weightRecordDays: records.weightRecords.map(\.day))
    }
}
