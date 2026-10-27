extension GoalOverview {
    /// 今の目標のカード。目標の状態ごとに、上の行・大きな1行・下の行・ボタンを分ける。減量・増量の進行中は、目標そのもの（期限の日と目標体重）だけを書く
    public struct Card: Hashable, Sendable {
        /// 上の行。「減量 9月1日〜11月30日」「維持 9月1日から・期限なし」
        public let summary: String
        /// 大きな1行
        public let title: String
        /// 下の行。減量・増量の進行中と、維持で体重の傾向がまだ無いときは nil
        public let detail: String?
        /// 期限が来たあとに達成したときだけ足す1行
        public let lateAchievement: String?
        public let action: Action
        /// 切り替える流れを広げているあいだ、カードの下に添える文。「今の目標（減量・11月30日までに 70.0 kg）は、新しい目標が決まるまで続きます。」
        public let continuingNote: String

        public init(
            summary: String, title: String, detail: String?, lateAchievement: String?,
            action: Action, continuingNote: String
        ) {
            self.summary = summary
            self.title = title
            self.detail = detail
            self.lateAchievement = lateAchievement
            self.action = action
            self.continuingNote = continuingNote
        }

        /// 目標がなければ nil
        init?(status: GoalStatus, today: CalendarDay, records: GoalRecords) {
            switch status {
            case .noGoal:
                return nil
            case .inProgress(let goal):
                self.init(inProgress: goal, today: today, records: records)
            case .achievedBeforeDeadline(let goal):
                self.init(achieved: goal, today: today, records: records)
            case .deadlineReached(let goal):
                self.init(deadlineReached: goal, records: records)
            case .maintainingAfterDeadline(let goal, let previous):
                let deadline = previous.direction.weightChange.map {
                    "\(GoalText.monthDay($0.deadlineDay))の期限のあと"
                }
                self.init(
                    summary: Self.summary(of: goal), title: Self.keepingTitle(goal),
                    detail: [
                        Self.bandDetail(goal: goal, today: today, records: records).map {
                            "\($0)。"
                        },
                        "\(deadline ?? "期限のあと")次の目標を選ばなかったので、\(Self.keepingTitle(goal))目標で続けています。",
                    ].compactMap(\.self).joined(),
                    lateAchievement: nil, action: .setNextGoal,
                    continuingNote: Self.continuingNote(goal))
            }
        }

        private init(inProgress goal: Goal, today: CalendarDay, records: GoalRecords) {
            guard let weightChange = goal.direction.weightChange else {
                self.init(
                    summary: Self.summary(of: goal), title: Self.keepingTitle(goal),
                    detail: Self.bandDetail(goal: goal, today: today, records: records),
                    lateAchievement: nil, action: .switchGoal,
                    continuingNote: Self.continuingNote(goal))
                return
            }
            // あと何 kg・あと何日・ペースは、体重の傾向のカードに置く（`WeightChart.Progress`）
            self.init(
                summary: Self.summary(of: goal),
                title:
                    "\(GoalText.monthDay(weightChange.deadlineDay))までに \(WeightAmountText.kilograms(goal.targetWeightKilograms))",
                detail: nil, lateAchievement: nil, action: .switchGoal,
                continuingNote: Self.continuingNote(goal))
        }

        private init(achieved goal: Goal, today: CalendarDay, records: GoalRecords) {
            let early: String? =
                if let achievement = goal.achievement,
                    let weightChange = goal.direction.weightChange
                {
                    "期限より \(achievement.achievedDay.distance(to: weightChange.deadlineDay)) 日早い"
                } else { nil }
            let trend = records.trendKilograms(onOrBefore: today).map {
                "傾向 \(WeightAmountText.kilograms($0))"
            }
            let facts = [early, trend].compactMap(\.self)
            self.init(
                summary: Self.summary(of: goal),
                title: "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を達成しました",
                detail: facts.isEmpty ? nil : facts.joined(separator: "・"),
                lateAchievement: nil, action: .chooseNextGoal,
                continuingNote: Self.continuingNote(goal))
        }

        private init(deadlineReached goal: Goal, records: GoalRecords) {
            let result = DeadlineResult(goal: goal, records: records)
            // 期限の日より後の最初の月曜に、期限後の維持に移る
            let maintenanceDay = goal.direction.weightChange.map(\.deadlineDay.firstMondayAfter)
            let title = result.map {
                "\(WeightAmountText.kilograms($0.deadlineWeightTrendKilograms)) で期限を迎えました"
            }
            let fallback = maintenanceDay.map {
                "選ばなければ、\(GoalText.monthDayWithWeekday($0))から今の体重を保つ目標で続けます。"
            }
            self.init(
                summary: Self.summary(of: goal), title: title ?? "期限を迎えました",
                detail: [result.map { "\($0.text)。" }, fallback].compactMap(\.self).joined(),
                lateAchievement: goal.achievement.map {
                    "\(GoalText.monthDay($0.achievedDay))に \(WeightAmountText.kilograms(goal.targetWeightKilograms)) を達成しました"
                },
                action: .chooseNextGoal, continuingNote: Self.continuingNote(goal))
        }

        /// 「減量 9月1日〜11月30日」「維持 9月1日から・期限なし」
        private static func summary(of goal: Goal) -> String {
            let name = GoalText.directionName(goal.direction)
            guard let weightChange = goal.direction.weightChange else {
                return "\(name) \(GoalText.monthDay(goal.startedDay))から・期限なし"
            }
            return "\(name) \(GoalText.dayRange(goal.startedDay, weightChange.deadlineDay))"
        }

        /// 「今の目標（減量・11月30日までに 70.0 kg）は、新しい目標が決まるまで続きます。」維持は「維持・72.0 kg を保つ」
        private static func continuingNote(_ goal: Goal) -> String {
            let name = GoalText.directionName(goal.direction)
            let target = WeightAmountText.kilograms(goal.targetWeightKilograms)
            let current =
                if let weightChange = goal.direction.weightChange {
                    "\(name)・\(GoalText.monthDay(weightChange.deadlineDay))までに \(target)"
                } else {
                    "\(name)・\(target) を保つ"
                }
            return "今の目標（\(current)）は、新しい目標が決まるまで続きます。"
        }

        /// 「72.0 kg を保つ」
        private static func keepingTitle(_ goal: Goal) -> String {
            "\(WeightAmountText.kilograms(goal.targetWeightKilograms)) を保つ"
        }

        /// 「傾向 72.3 kg・保てています」。体重の傾向がまだ無ければ nil
        private static func bandDetail(goal: Goal, today: CalendarDay, records: GoalRecords)
            -> String?
        {
            guard let trend = records.trendKilograms(onOrBefore: today),
                case .maintenance(let isWithinBand) = Pace(
                    judgedDay: today, goal: goal, achievedDay: nil,
                    weightTrend: records.weightTrend,
                    weightRecordDays: records.weightRecords.map(\.day))
            else { return nil }
            return
                "傾向 \(WeightAmountText.kilograms(trend))・\(isWithinBand ? "保てています" : "保てていません")"
        }

        public enum Action: Hashable, Sendable {
            /// 右上の「目標を切り替える」
            case switchGoal
            /// 塗った「次の目標を選ぶ」
            case chooseNextGoal
            /// 塗った「次の目標を立てる」
            case setNextGoal
        }
    }
}
