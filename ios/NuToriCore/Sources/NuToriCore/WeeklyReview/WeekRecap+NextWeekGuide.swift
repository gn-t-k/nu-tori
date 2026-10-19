extension WeekRecap {
    /// 一番下の、次の週の1日の目安と、変わった理由（見送った週は、そのままの理由）の文
    public struct NextWeekGuide: Hashable, Sendable {
        public let energyKilocalories: Int
        /// 前の週からの変化。見送った週は nil
        public let changeKilocalories: Int?
        public let sentence: String

        public init(energyKilocalories: Int, changeKilocalories: Int?, sentence: String) {
            self.energyKilocalories = energyKilocalories
            self.changeKilocalories = changeKilocalories
            self.sentence = sentence
        }

        /// 見直していない週、指す記録がまだ届いていない週、月曜に立て直して見直した1日の目安が1日も当たらない週は nil
        /// - Parameters:
        ///   - guideOfWeek: その週に当たっていた1日の目安
        ///   - meals: 食事のカード。見送った週の、食事を記録した日を数える
        init?(
            monday: CalendarDay, guideOfWeek: DailyGuide?, records: GoalRecords, meals: [MealCard]
        ) {
            let nextMonday = monday.advanced(by: 7)
            guard let guideOfWeek,
                let review = records.weeklyReviews.first(where: { $0.effectiveDay == nextMonday })
            else { return nil }
            let previous = NutritionText.number(
                .exactly(Double(guideOfWeek.energyKilocalories)), of: .energyKcal)
            switch review.outcome {
            case .deferred(let reason, _):
                let because: String
                switch reason {
                case .withinFirstWeek:
                    because = "使い始めて7日たっていないためです。"
                case .noWeight:
                    because = "体重の記録が無かったためです。"
                case .fewMealRecords:
                    // サーバーは部分的な記録の日を数えないので、数えた日がサーバーより多いことがある。
                    // 見送りの決まり（4日未満）に当たる数のときだけ日数を書く
                    let count = Self.recordedFoodDayCount(
                        in: monday...monday.advanced(by: 6), meals: meals)
                    because =
                        count < 4 ? "食事の記録が \(count) 日だったためです。" : "食事の記録が少なかったためです。"
                }
                self.init(
                    energyKilocalories: guideOfWeek.energyKilocalories, changeKilocalories: nil,
                    sentence: "\(previous) kcal のままです。\(because)")
            case .reviewed(let estimateId, let guideId, let mainReason):
                guard let guide = records.dailyGuides.first(where: { $0.id == guideId }),
                    let estimate = records.expenditureEstimates.first(where: { $0.id == estimateId }
                    ),
                    let previousEstimate = records.expenditureEstimates.first(where: {
                        $0.id == guideOfWeek.expenditureEstimateId
                    }),
                    let goal = records.goals.first(where: { $0.id == guide.goalId }),
                    DailyGuideForDay(
                        on: nextMonday, goals: records.goals, dailyGuides: records.dailyGuides)?
                        .goal.id == goal.id
                else { return nil }
                let reason = Self.reason(
                    mainReason: mainReason, goal: goal, nextMonday: nextMonday,
                    change: guide.energyKilocalories - guideOfWeek.energyKilocalories,
                    previousEstimate: previousEstimate, estimate: estimate, goals: records.goals)
                let limits = guide.limitHits.map {
                    Self.limitSentence($0, direction: goal.direction)
                }
                let current = NutritionText.kilocalories(guide.energyKilocalories)
                self.init(
                    energyKilocalories: guide.energyKilocalories,
                    changeKilocalories: guide.energyKilocalories - guideOfWeek.energyKilocalories,
                    sentence: "\(previous) → \(current)。\(reason)推移は目標で見られます。"
                        + limits.joined())
            }
        }

        /// 「−30 kcal」。見送った週は「そのまま」
        public var changeText: String {
            changeKilocalories.map(GoalText.signedKilocalories) ?? "そのまま"
        }

        private static func reason(
            mainReason: WeeklyReview.MainReason, goal: Goal, nextMonday: CalendarDay, change: Int,
            previousEstimate: ExpenditureEstimate, estimate: ExpenditureEstimate, goals: [Goal]
        ) -> String {
            let movedToMaintenance = goals.contains {
                $0.closure?.nextGoalId == goal.id && $0.closure?.endReason == .movedToMaintenance
            }
            if movedToMaintenance, goal.startedDay == nextMonday {
                return "今の体重を保つ目標に切り替えたためです。"
            }
            switch mainReason {
            case .expenditureChange:
                let from = NutritionText.number(
                    .exactly(Double(previousEstimate.expenditureKilocalories)), of: .energyKcal)
                let to = NutritionText.kilocalories(estimate.expenditureKilocalories)
                let moved =
                    estimate.expenditureKilocalories > previousEstimate.expenditureKilocalories
                    ? "上がった" : "下がった"
                return "推定消費カロリーが \(from) から \(to) に\(moved)ためです。"
            case .balanceChange:
                return balanceReason(goal: goal, nextMonday: nextMonday, change: change)
            }
        }

        /// 1日に減らす（足す）分の変化の理由。目標に向かう側へ1日の目安が動いたら、期限までの日が減って分を増やした
        private static func balanceReason(goal: Goal, nextMonday: CalendarDay, change: Int)
            -> String
        {
            let towardTarget: Bool
            let amount: String
            switch goal.direction {
            case .lose:
                amount = "減らす分"
                towardTarget = change <= 0
            case .gain:
                amount = "足す分"
                towardTarget = change >= 0
            case .maintain:
                return "体重の傾向に合わせて、1日に戻す分を変えたためです。"
            }
            if let achievement = goal.achievement, achievement.achievedDay < nextMonday {
                return "目標に届いたので、1日に\(amount)をなくしていくためです。"
            }
            return towardTarget
                ? "期限までの日が減り、1日に\(amount)を増やしたためです。"
                : "予定より進んでいるので、1日に\(amount)を減らしたためです。"
        }

        private static func limitSentence(_ hit: DailyGuide.LimitHit, direction: Goal.Direction)
            -> String
        {
            switch hit {
            case .weeklyChange:
                return "1週間に変える量は 150 kcal までにしています。"
            case .requiredPace:
                switch direction {
                case .lose: return "減らす速さは、1週間に体重の 0.75% までにしています。"
                case .gain: return "足す速さは、1週間に体重の 0.5% までにしています。"
                case .maintain: return "戻す速さは、1週間に体重の 0.15% までにしています。"
                }
            case .minimumEnergy:
                return
                    "1日の目安は \(NutritionText.kilocalories(DailyGuide.minimumEnergyKilocalories)) より下げません。"
            }
        }

        /// 食べた量（kcal）が分かった日の数
        private static func recordedFoodDayCount(
            in days: ClosedRange<CalendarDay>, meals: [MealCard]
        ) -> Int {
            Dictionary(grouping: meals.filter { days.contains($0.meal.day) }, by: \.meal.day)
                .values
                .count { DayFood(meals: $0).figures?.totals[.energyKcal].value != nil }
        }
    }
}
