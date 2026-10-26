extension GoalOverview {
    /// 今の推定消費カロリーと1日の目安の棒と、見直した点が3つたまってから描く、推定消費カロリーの線と1日の目安の階段を重ねたグラフ
    public struct EnergyChart: Hashable, Sendable {
        public let bars: Bars
        /// 見直した点が3つたまるまでは nil
        public let graph: Graph?

        /// 減量・増量・維持の進行中と期限後の維持だけで出す。今の1日の目安か、その推定消費カロリーがまだ届いていなければ nil
        /// - Parameter dailyGuide: 今日に当たっている今の目標の1日の目安（`CurrentGoal.dailyGuide`）
        init?(
            status: GoalStatus, today: CalendarDay, dailyGuide: DailyGuide?, records: GoalRecords
        ) {
            let goal: Goal
            switch status {
            case .inProgress(let current), .maintainingAfterDeadline(let current, _):
                goal = current
            case .noGoal, .achievedBeforeDeadline, .deadlineReached:
                return nil
            }
            guard let dailyGuide,
                let estimate = records.expenditureEstimates.first(where: {
                    $0.id == dailyGuide.expenditureEstimateId
                })
            else { return nil }
            bars = Bars(
                expenditureKilocalories: estimate.expenditureKilocalories,
                dailyGuideKilocalories: dailyGuide.energyKilocalories)
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
            guard points.count >= Self.minimumPointsToDraw else {
                graph = nil
                return
            }
            let days =
                goal
                .startedDay...max(
                    goal.startedDay, goal.direction.weightChange?.deadlineDay ?? today)
            graph = Graph(
                days: days, points: points,
                deferredDays: records.weeklyReviews.compactMap { review in
                    guard case .deferred(_, let goalId) = review.outcome, goalId == goal.id,
                        days.contains(review.effectiveDay)
                    else { return nil }
                    return review.effectiveDay
                }.sorted())
        }

        /// 0 kcal からの同じ目盛りで並べる、今の推定消費カロリーと1日の目安
        public struct Bars: Hashable, Sendable {
            public let expenditureKilocalories: Int
            public let dailyGuideKilocalories: Int

            public init(expenditureKilocalories: Int, dailyGuideKilocalories: Int) {
                self.expenditureKilocalories = expenditureKilocalories
                self.dailyGuideKilocalories = dailyGuideKilocalories
            }

            /// 2本の差。「減らす分 −440 kcal」「足す分 +300 kcal」。同じなら nil
            public var gap: String? {
                let difference = dailyGuideKilocalories - expenditureKilocalories
                guard difference != 0 else { return nil }
                return
                    "\(difference < 0 ? "減らす分" : "足す分") \(GoalText.signedKilocalories(difference))"
            }
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
        /// グラフの上に書く進み具合。減量・増量の進行中だけ
        public let progress: Progress?

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
            progress =
                if case .inProgress = status {
                    Progress(goal: goal, today: today, records: records)
                } else { nil }
        }

        /// 「あと 2.8 kg」「あと 45 日」「間に合うペースです」
        public struct Progress: Hashable, Sendable {
            /// 「あと 2.8 kg」。体重の傾向がまだ無ければ nil
            public let remainingKilograms: String?
            /// 「あと 45 日」。今日と期限の日を含める
            public let remainingDays: String
            /// 返さないペースでは nil
            public let pace: String?

            public init(remainingKilograms: String?, remainingDays: String, pace: String?) {
                self.remainingKilograms = remainingKilograms
                self.remainingDays = remainingDays
                self.pace = pace
            }

            /// 維持の目標は nil
            init?(goal: Goal, today: CalendarDay, records: GoalRecords) {
                guard let weightChange = goal.direction.weightChange else { return nil }
                remainingKilograms =
                    if case .weightChange(let tenths, _) = GoalProgress(
                        goal: goal, today: today, weightTrend: records.weightTrend)
                    {
                        "あと \(GoalText.kilograms(tenths: tenths))"
                    } else { nil }
                remainingDays = "あと \(max(today.distance(to: weightChange.deadlineDay) + 1, 0)) 日"
                pace = Pace(
                    judgedDay: today, goal: goal, achievedDay: goal.achievement?.achievedDay,
                    weightTrend: records.weightTrend,
                    weightRecordDays: records.weightRecords.map(\.day)
                ).flatMap(Self.paceText)
            }

            /// 減量・増量の進行中に書くペース。返さないときは書かない
            private static func paceText(_ pace: Pace) -> String? {
                switch pace {
                case .onTrack: "間に合うペースです"
                case .behind(let shortfall, _, _):
                    "このままだと期限に \(GoalText.kilograms(tenths: shortfall)) 届きません"
                case .inconclusive: "間に合うかはまだわかりません"
                case .pending: "間に合うかは、目標を立てて 14 日たつと出ます"
                case .unavailable, .maintenance: nil
                }
            }
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

        /// 結果の「−3.6 kg」
        public var resultText: String? {
            endWeightKilograms.map {
                GoalText.signedKilograms(
                    tenths: GoalText.tenths($0 - goal.startingWeightTrendKilograms))
            }
        }
    }
}
