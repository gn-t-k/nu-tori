extension WeekRecap {
    /// 一番上の、太字の1行と、その下の文かペースの値の行。ペースが出る週は「いまのペース」「要るペース」の値の行を並べ、
    /// ペースが返らない週（達成した、期限の日を迎えた）は、その週に起きたことを文で書く
    public struct TopLine: Hashable, Sendable {
        public let headline: String
        /// ペースの値の行を並べる週は nil
        public let sentence: String?
        public let paceRows: [PaceRow]

        public init(headline: String, sentence: String?, paceRows: [PaceRow] = []) {
            self.headline = headline
            self.sentence = sentence
            self.paceRows = paceRows
        }

        /// 「いまのペース　−0.5 kg／週」
        public struct PaceRow: Hashable, Sendable {
            public let label: String
            public let value: String

            public init(label: String, value: String) {
                self.label = label
                self.value = value
            }
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
                    headline: "間に合うペースです", sentence: nil,
                    paceRows: Self.paceRows(actual: actual, required: required))
            case .behind(let shortfall, let actual, let required):
                self.init(
                    headline: "このままだと期限に \(GoalText.kilograms(tenths: shortfall)) 届きません",
                    sentence: nil, paceRows: Self.paceRows(actual: actual, required: required))
            case .inconclusive(let count):
                self.init(
                    headline: "間に合うかはまだわかりません",
                    sentence: "直近 14 日の体重の記録が \(count) 日なので、傾向が定まっていません。")
            case .pending:
                self.init(
                    headline: "間に合うかはまだわかりません", sentence: "目標を立てて 14 日たつと出ます。")
            case .unavailable:
                self.init(unavailableFor: goal, judgedDay: judgedDay, records: records)
            case .maintenance(let isWithinBand):
                guard let trend = records.trendKilograms(onOrBefore: judgedDay) else { return nil }
                let range = GoalStateText.maintenanceRange(goal)
                self.init(
                    headline: isWithinBand ? "保てています" : "保てていません",
                    sentence:
                        "体重の傾向は \(WeightAmountText.kilograms(trend)) で、\(range)\(isWithinBand ? "に入っています。" : "から外れています。")"
                )
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

        /// 「いまのペース　−0.5 kg／週」「要るペース　−0.3 kg／週」。いまは体重の傾向の速さ、要るは期限に目標体重へ届く速さ
        private static func paceRows(actual: Int, required: Int) -> [PaceRow] {
            [
                PaceRow(label: "いまのペース", value: "\(GoalText.signedKilograms(tenths: actual))／週"),
                PaceRow(label: "要るペース", value: "\(GoalText.signedKilograms(tenths: required))／週"),
            ]
        }
    }
}
