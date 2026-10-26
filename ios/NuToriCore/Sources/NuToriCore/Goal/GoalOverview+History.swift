extension GoalOverview {
    /// 推定消費カロリーの線と1日の目安の階段を重ねたグラフ。見直した点が3つたまるまでは、グラフの代わりに今の値の数字
    public enum EnergyChart: Hashable, Sendable {
        case drawn(Graph)
        /// 「推定消費カロリー 2,250 kcal」「1日の目安 1,900 kcal」「1日の目安は推定消費カロリーより 350 kcal 少ない」
        case figures([String])

        /// 減量・増量・維持の進行中と期限後の維持だけで出す。今の目標の1日の目安がまだ届いていなければ nil
        init?(status: GoalStatus, today: CalendarDay, records: GoalRecords) {
            let goal: Goal
            switch status {
            case .inProgress(let current), .maintainingAfterDeadline(let current, _):
                goal = current
            case .noGoal, .achievedBeforeDeadline, .deadlineReached:
                return nil
            }
            let points = records.dailyGuides
                .filter { $0.goalId == goal.id }
                .sorted { $0.effectiveDay < $1.effectiveDay }
                .compactMap { guide -> Point? in
                    guard
                        let estimate = records.expenditureEstimates.first(where: {
                            $0.id == guide.expenditureEstimateId
                        })
                    else { return nil }
                    return Point(
                        day: guide.effectiveDay,
                        expenditureKilocalories: estimate.expenditureKilocalories,
                        dailyGuideKilocalories: guide.energyKilocalories)
                }
            guard let latest = points.last else { return nil }
            guard points.count >= Self.minimumPointsToDraw else {
                self = .figures([
                    "推定消費カロリー \(NutritionText.kilocalories(latest.expenditureKilocalories))",
                    "1日の目安 \(NutritionText.kilocalories(latest.dailyGuideKilocalories))",
                    Self.balanceText(of: latest),
                ])
                return
            }
            let days =
                goal
                .startedDay...max(
                    goal.startedDay, goal.direction.weightChange?.deadlineDay ?? today)
            self = .drawn(
                Graph(
                    days: days, points: points,
                    deferredDays: records.weeklyReviews.compactMap { review in
                        guard case .deferred(_, let goalId) = review.outcome, goalId == goal.id,
                            days.contains(review.effectiveDay)
                        else { return nil }
                        return review.effectiveDay
                    }.sorted()))
        }

        /// 「1日の目安は推定消費カロリーより 350 kcal 少ない」
        private static func balanceText(of point: Point) -> String {
            let difference = point.dailyGuideKilocalories - point.expenditureKilocalories
            if difference == 0 { return "1日の目安は推定消費カロリーと同じ" }
            return
                "1日の目安は推定消費カロリーより \(NutritionText.kilocalories(abs(difference))) \(difference < 0 ? "少ない" : "多い")"
        }

        /// 初めの推定と、見直した2回
        private static let minimumPointsToDraw = 3

        public struct Graph: Hashable, Sendable {
            /// 横軸。今の目標の開始の日から期限の日まで（維持は今日まで）
            public let days: ClosedRange<CalendarDay>
            /// 1日の目安の当てる始まりの日ごとの点。日の順
            public let points: [Point]
            /// 見送った週の、前の週のままにした月曜。階段に「見送り」の印を付ける
            public let deferredDays: [CalendarDay]

            public init(
                days: ClosedRange<CalendarDay>, points: [Point], deferredDays: [CalendarDay]
            ) {
                self.days = days
                self.points = points
                self.deferredDays = deferredDays
            }
        }

        public struct Point: Hashable, Sendable {
            /// 1日の目安を当て始めた日
            public let day: CalendarDay
            public let expenditureKilocalories: Int
            public let dailyGuideKilocalories: Int

            public init(day: CalendarDay, expenditureKilocalories: Int, dailyGuideKilocalories: Int)
            {
                self.day = day
                self.expenditureKilocalories = expenditureKilocalories
                self.dailyGuideKilocalories = dailyGuideKilocalories
            }
        }
    }

    /// 体重の傾向のグラフ。使い始める前の記録は、目標の開始の日より前なので入らない
    public struct WeightChart: Hashable, Sendable {
        /// 「体重の傾向」。期限が来たときは「体重の歩み」
        public let title: String
        /// 横軸。開始の日から期限の日まで（維持は今日まで）
        public let days: ClosedRange<CalendarDay>
        /// 横軸の中の、届いた傾向の日の値
        public let trend: [WeightTrend.Day]

        init(status: GoalStatus, goal: Goal, today: CalendarDay, records: GoalRecords) {
            if case .deadlineReached = status {
                title = "体重の歩み"
            } else {
                title = "体重の傾向"
            }
            let days =
                goal
                .startedDay...max(
                    goal.startedDay, goal.direction.weightChange?.deadlineDay ?? today)
            self.days = days
            trend = records.weightTrend?.days.filter { days.contains($0.day) } ?? []
        }
    }

    /// 過去の目標の行。潜らない
    public struct PastGoal: Hashable, Sendable {
        public let goal: Goal
        /// 行に書く終わりの日。期限の日以降に閉じた目標は期限の日、ほかは終わった日の前の日
        public let lastDay: CalendarDay
        /// 終わりの体重の傾向。期限の日以降に閉じた目標は期限の日の傾向。まだ無ければ nil
        public let endWeightKilograms: Double?

        /// 閉じていない目標と、0日の目標（どの日にも当たらない）は nil
        init?(goal: Goal, records: GoalRecords) {
            guard let closure = goal.closure, closure.endedDay > goal.startedDay else { return nil }
            self.goal = goal
            if let weightChange = goal.direction.weightChange,
                closure.endedDay >= weightChange.deadlineDay
            {
                lastDay = weightChange.deadlineDay
                endWeightKilograms =
                    DeadlineResult(goal: goal, records: records)?
                    .deadlineWeightTrendKilograms
            } else {
                lastDay = closure.endedDay.advanced(by: -1)
                endWeightKilograms = records.trendKilograms(onOrBefore: closure.endedDay)
            }
        }

        /// 「減量 9月1日〜11月30日」
        public var summary: String {
            "\(GoalText.directionName(goal.direction)) \(GoalText.dayRange(goal.startedDay, lastDay))"
        }

        /// 「74.0 → 70.4 kg」
        public var weightsText: String? {
            endWeightKilograms.map {
                GoalText.kilogramsChange(from: goal.startingWeightTrendKilograms, to: $0)
            }
        }
    }
}
