/// 体重の画面の、目標までの道のり。一覧の行と、ペースの注記。最後に「目標 ›」を置く。
/// 今日の体重の傾向から出す（日のまとめと同じ値）
public struct WeightGoalPath: Hashable, Sendable {
    public let rows: [Row]
    /// 一覧の下の注記。進行中だけに出す
    public let note: String?

    /// 目標がないときは nil（今の「目標を立てる」のまま）
    /// - Parameter today: 端末の今のタイムゾーンでの今日
    public init?(status: GoalStatus, today: CalendarDay, records: GoalRecords) {
        switch status {
        case .noGoal:
            return nil
        case .inProgress(let goal):
            guard let weightChange = goal.direction.weightChange else {
                rows = [Row(label: "維持", value: GoalStateText.keeping(goal))]
                note = GoalStateText.isWithinBand(goal, day: today, records: records).map {
                    $0 ? "体重の傾向は保つ幅に入っています。" : "体重の傾向は保つ幅から外れています。"
                }
                return
            }
            let target = "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) まで"
            let progress = GoalProgress(goal: goal, today: today, weightTrend: records.weightTrend)
            let remaining: String =
                if case .weightChange(let tenths, _) = progress {
                    " あと \(GoalText.kilograms(tenths: tenths))"
                } else { "" }
            // 両端を含めて数える（`GoalProgress` と同じ）。期限を過ぎたら 0 で止める
            let remainingDays = max(today.distance(to: weightChange.deadlineDay) + 1, 0)
            rows = [
                Row(label: GoalText.directionName(goal.direction), value: target + remaining),
                Row(
                    label: "期限",
                    value: "\(GoalText.monthDay(weightChange.deadlineDay)) あと \(remainingDays) 日"),
            ]
            note = GoalStateText.pace(goal, day: today, records: records).flatMap(Self.paceNote)
        case .achievedBeforeDeadline(let goal):
            rows = [
                Row(
                    label: GoalText.directionName(goal.direction),
                    value: GoalStateText.achieved(goal))
            ]
            note = nil
        case .deadlineReached(let goal):
            rows = [
                Row(
                    label: GoalText.directionName(goal.direction),
                    value: GoalStateText.deadlineReached(goal, records: records))
            ]
            note = nil
        case .maintainingAfterDeadline(let goal, _):
            rows = [
                Row(
                    label: "維持",
                    value: GoalStateText.keepingWithBand(goal, day: today, records: records))
            ]
            note = nil
        }
    }

    private static func paceNote(_ pace: Pace) -> String? {
        switch pace {
        case .onTrack(let actual, _):
            "最近の傾向は \(GoalText.signedKilograms(tenths: actual))／週で、期限に間に合うペースです。"
        case .behind(let shortfall, _, _):
            "このままだと期限に \(GoalText.kilograms(tenths: shortfall)) 届きません。"
        case .inconclusive:
            "体重の記録が少なく、ペースはまだ言い切れません。"
        case .pending:
            "ペースは目標を立てて 14 日たつと出ます。"
        case .unavailable, .maintenance:
            nil
        }
    }

    /// 「減量　70.0 kg まで あと 2.8 kg」
    public struct Row: Hashable, Sendable {
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }
}
