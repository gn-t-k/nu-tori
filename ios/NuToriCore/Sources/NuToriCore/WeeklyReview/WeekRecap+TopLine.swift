extension WeekRecap {
    /// 一番上の、太字の1行と文。ペースが返らない週（達成した、期限の日を迎えた）は、その週に起きたことを書く
    public struct TopLine: Hashable, Sendable {
        public let headline: String
        public let sentence: String

        public init(headline: String, sentence: String) {
            self.headline = headline
            self.sentence = sentence
        }

        /// 判定に要る体重の傾向がまだ届いていなければ nil
        /// - Parameter judgedDay: その週の日曜。今週は今日
        init?(goal: Goal, judgedDay: CalendarDay, records: GoalRecords) {
            guard
                let pace = Pace(
                    judgedDay: judgedDay, goal: goal, achievedDay: goal.achievement?.achievedDay,
                    weightTrend: records.weightTrend,
                    weightRecordDays: records.weightRecords.map(\.day))
            else { return nil }
            switch pace {
            case .onTrack(let actual, let required):
                self.init(
                    headline: "間に合うペースです",
                    sentence: Self.paceSentence(goal: goal, actual: actual, required: required))
            case .behind(let shortfall, let actual, let required):
                self.init(
                    headline: "このままだと期限に \(GoalText.kilograms(tenths: shortfall)) 届きません",
                    sentence: Self.paceSentence(goal: goal, actual: actual, required: required))
            case .inconclusive(let count):
                self.init(
                    headline: "まだ言い切れません",
                    sentence: "直近 14 日の体重の記録が \(count) 日なので、傾向が定まっていません。")
            case .pending:
                self.init(
                    headline: "まだ言い切れません", sentence: "目標を立てて 14 日たつと、間に合うペースかを出します。")
            case .unavailable:
                self.init(unavailableFor: goal, judgedDay: judgedDay, records: records)
            case .maintenance(let isWithinBand):
                guard let trend = records.trendKilograms(onOrBefore: judgedDay) else { return nil }
                let band =
                    "体重の傾向は \(WeightAmountText.kilograms(trend)) で、\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を保つ幅（±0.7 kg）"
                self.init(
                    headline: isWithinBand ? "保てています" : "幅から外れています",
                    sentence: isWithinBand ? "\(band)に入っています。" : "\(band)から外れています。")
            }
        }

        /// ペースを返さない週。期限の日より前に達成していれば達成（達成した週と、そのあとの週で分ける）、ほかは期限の日を迎えた
        private init?(unavailableFor goal: Goal, judgedDay: CalendarDay, records: GoalRecords) {
            guard let weightChange = goal.direction.weightChange else { return nil }
            let deadline = weightChange.deadlineDay
            if let achievement = goal.achievement, achievement.achievedDay <= judgedDay,
                achievement.achievedDay <= deadline
            {
                let reached =
                    "\(GoalText.monthDay(achievement.achievedDay))に、体重の傾向が \(WeightAmountText.kilograms(goal.targetWeightKilograms)) に届きました。"
                if achievement.achievedDay >= judgedDay.startOfWeek {
                    self.init(headline: "目標に届いた週です", sentence: reached)
                } else {
                    // 次の目標を選ぶまでは、達成した目標が続く。選んだあとの目標の週には、選べるとは書かない
                    self.init(
                        headline: "目標に届いています",
                        sentence: goal.closure == nil ? "\(reached)次の目標を選べます。" : reached)
                }
                return
            }
            let result = DeadlineResult(goal: goal, records: records).map {
                "\(GoalText.monthDay(deadline))の結果は、\($0.text) でした。"
            }
            self.init(
                headline: "期限の週です", sentence: result ?? "\(GoalText.monthDay(deadline))が期限でした。")
        }

        /// 「傾向で1週間に −0.5 kg。期限の11月30日に 70.0 kg へは、1週間に −0.3 kg で届きます。」
        private static func paceSentence(goal: Goal, actual: Int, required: Int) -> String {
            let deadline = goal.direction.weightChange.map {
                "期限の\(GoalText.monthDay($0.deadlineDay))"
            }
            return
                "傾向で1週間に \(GoalText.signedKilograms(tenths: actual))。\(deadline ?? "期限")に \(WeightAmountText.kilograms(goal.targetWeightKilograms)) へは、1週間に \(GoalText.signedKilograms(tenths: required)) で届きます。"
        }
    }
}
