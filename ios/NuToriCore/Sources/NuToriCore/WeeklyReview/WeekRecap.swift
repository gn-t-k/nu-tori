/// 週の振り返りに描くもの。週は、新しい1日の目安を当てた月曜の前の月〜日。
/// キャッシュの目標・1日の目安・推定消費カロリー・週の見直し・体重・食事から組む（電波が無くても、届いている記録のままに見せるため）
public struct WeekRecap: Hashable, Sendable {
    /// その週の月曜
    public let monday: CalendarDay
    /// その週の目標（日曜を含む目標）。何週目かは、この目標の開始の日から数える
    public let goal: Goal
    /// その目標の何週目か。開始の日を含む週が1週目
    public let weekNumber: Int
    /// 今日を含む週（まだ見直していない今週）。次の週の1日の目安を出さない
    public let isInProgress: Bool
    /// 並べる日。目標を立てた週は立てた日から、今週は今日まで
    public let days: [Day]
    /// その週に当たっていた1日の目安（日曜の1日の目安）。まだ届いていなければ nil
    public let dailyGuide: DailyGuide?
    /// 食べた量が分かった日の平均。そういう日が無ければ nil
    public let averageFood: AverageFood?
    public let weight: Weight
    /// 一番上のペース。判定に要る体重の傾向がまだ届いていなければ nil
    public let topLine: TopLine?
    /// 次の週の1日の目安。今週と、見直しやその指す記録がまだ届いていない週は nil
    public let nextWeekGuide: NextWeekGuide?

    /// その週の日曜を含む目標が無ければ（目標を立てる前の週）nil
    /// - Parameters:
    ///   - day: その週の日のどれか
    ///   - today: 端末の今のタイムゾーンでの今日
    ///   - meals: 食事のカード。食事の日でその日に入れる
    public init?(
        weekOf day: CalendarDay, today: CalendarDay, records: GoalRecords, meals: [MealCard]
    ) {
        let monday = day.startOfWeek
        let sunday = monday.advanced(by: 6)
        guard
            let guideOfWeek = DailyGuideForDay(
                on: sunday, goals: records.goals, dailyGuides: records.dailyGuides)
        else { return nil }
        let goal = guideOfWeek.goal
        self.monday = monday
        self.goal = goal
        dailyGuide = guideOfWeek.dailyGuide
        weekNumber = goal.startedDay.startOfWeek.distance(to: monday) / 7 + 1
        isInProgress = today <= sunday
        let mealsByDay = Dictionary(grouping: meals, by: \.meal.day)
        let weightsByDay = Dictionary(
            RepresentativeWeight.daily(of: records.weightRecords).map {
                ($0.day, $0.record.kilograms)
            },
            uniquingKeysWith: { first, _ in first })
        let firstShownDay = max(monday, goal.startedDay)
        let lastShownDay = max(firstShownDay, min(sunday, today))
        days = (firstShownDay...lastShownDay).map {
            Day(
                day: $0, food: DayFood(meals: mealsByDay[$0] ?? []),
                weightKilograms: weightsByDay[$0])
        }
        averageFood = AverageFood(days: days)
        weight = Weight(shownDays: firstShownDay...lastShownDay, days: days, records: records)
        topLine = TopLine(goal: goal, judgedDay: min(sunday, today), records: records)
        nextWeekGuide =
            isInProgress
            ? nil
            : NextWeekGuide(
                monday: monday, guideOfWeek: guideOfWeek.dailyGuide, records: records, meals: meals)
    }

    /// 「9月14日〜20日」。目標を立てた週は立てた日から。今週は「（途中）」を付ける
    public var title: String {
        let range = GoalText.dayRange(max(monday, goal.startedDay), monday.advanced(by: 6))
        return isInProgress ? "\(range)（途中）" : range
    }

    /// 「減量の3週目」
    public var weekLabel: String {
        "\(GoalText.directionName(goal.direction))の\(weekNumber)週目"
    }

    /// 目標を立てた週に、食べた量の下に添える文。見直しは立てた日より前を含めた月〜日を使うので、平均が見直しと一致しないため
    public var firstWeekNote: String? {
        guard goal.startedDay > monday else { return nil }
        return "1日の目安の見直しには、\(GoalText.dayRange(monday, monday.advanced(by: 6)))の 7 日の記録を使っています。"
    }

    /// 日ごとの行と、食べた量の棒・体重の点
    public struct Day: Hashable, Sendable {
        public let day: CalendarDay
        public let food: DayFood
        /// その日の体重の代表値。体重記録の無い日は nil
        public let weightKilograms: Double?

        public init(day: CalendarDay, food: DayFood, weightKilograms: Double?) {
            self.day = day
            self.food = food
            self.weightKilograms = weightKilograms
        }
    }

    /// 食べた量の1日の平均。記録の無い日で平均が下がらないよう、食べた量（kcal）が分かった日だけで出す
    public struct AverageFood: Hashable, Sendable {
        public let energyKilocalories: Int
        public let proteinGrams: Int
        public let fatGrams: Int
        public let carbohydrateGrams: Int
        /// 平均に入れた日の数
        public let recordedDayCount: Int
        /// 並べた日の数
        public let dayCount: Int

        init?(days: [Day]) {
            let totals = days.compactMap { $0.food.figures?.totals }.filter {
                $0[.energyKcal].value != nil
            }
            guard !totals.isEmpty else { return nil }
            func average(_ nutrient: Nutrient) -> Int {
                let sum = totals.reduce(0) { $0 + ($1[nutrient].value ?? 0) }
                return Int((sum / Double(totals.count)).rounded())
            }
            energyKilocalories = average(.energyKcal)
            proteinGrams = average(.proteinG)
            fatGrams = average(.fatG)
            carbohydrateGrams = average(.carbohydrateG)
            recordedDayCount = totals.count
            dayCount = days.count
        }

        /// 「平均」。記録の無い日があれば「記録した 5 日の平均」
        public var label: String {
            recordedDayCount == dayCount ? "平均" : "記録した \(recordedDayCount) 日の平均"
        }
    }
}
