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
                    // 見送りの決まりに当たる数のときだけ日数を書く
                    let count = Self.recordedFoodDayCount(
                        in: monday...monday.advanced(by: 6), meals: meals)
                    because =
                        count < WeeklyReview.minimumMealDayCount
                        ? "食事の記録が \(count) 日だったためです。" : "食事の記録が少なかったためです。"
                }
                self.init(
                    energyKilocalories: guideOfWeek.energyKilocalories, changeKilocalories: nil,
                    sentence: "\(previous) kcal のままです。\(because)")
            case .reviewed(_, let guideId, let mainReason):
                guard let guide = records.dailyGuides.first(where: { $0.id == guideId }),
                    let goal = records.goals.first(where: { $0.id == guide.goalId }),
                    DailyGuideForDay(
                        on: nextMonday, goals: records.goals, dailyGuides: records.dailyGuides)?
                        .goal.id == goal.id,
                    let reason = DailyGuideChangeReason(
                        mainReason: mainReason, from: guideOfWeek, to: guide, records: records)
                else { return nil }
                let limits = guide.limitHits.map {
                    Self.limitSentence($0, direction: goal.direction)
                }
                let current = NutritionText.kilocalories(guide.energyKilocalories)
                self.init(
                    energyKilocalories: guide.energyKilocalories,
                    changeKilocalories: guide.energyKilocalories - guideOfWeek.energyKilocalories,
                    sentence: "\(previous) → \(current)。\(reason.text)推移は目標で見られます。"
                        + limits.joined())
            }
        }

        /// 「−30 kcal」。見送った週は「そのまま」
        public var changeText: String {
            changeKilocalories.map(GoalText.signedKilocalories) ?? "そのまま"
        }

        private static func limitSentence(_ hit: DailyGuide.LimitHit, direction: Goal.Direction)
            -> String
        {
            switch hit {
            case .weeklyChange:
                return
                    "1週間に変える量は \(NutritionText.kilocalories(DailyGuide.weeklyChangeLimitKilocalories)) までにしています。"
            case .requiredPace:
                let verb =
                    switch direction {
                    case .lose: "減らす"
                    case .gain: "足す"
                    case .maintain: "戻す"
                    }
                return
                    "\(verb)速さは、1週間に体重の \(DailyGuide.requiredPaceLimitPercent(direction))% までにしています。"
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
