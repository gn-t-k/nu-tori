import Foundation
import NuToriCore
import Testing

/// 10月1日（木）に立てた、12月24日までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）の週の振り返り
@Suite("週の振り返り")
struct WeekRecapTests {
    static func day(_ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: month, day: day)
    }

    static func recap(
        weekOf day: CalendarDay, today: CalendarDay, goals: [Goal]? = nil,
        dailyGuides: [DailyGuide] = [], expenditureEstimates: [ExpenditureEstimate] = [],
        weeklyReviews: [WeeklyReview] = [], weightTrend: WeightTrend? = nil,
        weightRecords: [WeightRecord] = [], meals: [MealCard] = []
    ) throws -> WeekRecap? {
        WeekRecap(
            weekOf: day, today: today,
            records: GoalRecords(
                goals: try goals ?? [.losing()], dailyGuides: dailyGuides,
                expenditureEstimates: expenditureEstimates, weeklyReviews: weeklyReviews,
                weightTrend: weightTrend, weightRecords: weightRecords),
            meals: meals)
    }

    @Suite("週の日の並び")
    struct Days {
        @Test("目標を立てた週は、立てた日から日曜までを並べ、1週目にすること")
        func firstWeekStartsOnStartedDay() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(9, 30), today: WeekRecapTests.day(10, 10)))

            #expect(
                recap.days.map(\.day)
                    == Array(WeekRecapTests.day(10, 1)...WeekRecapTests.day(10, 4)))
            #expect(recap.weekNumber == 1)
            #expect(recap.title == "10月1日〜4日")
            #expect(recap.weekLabel == "減量の1週目")
        }

        @Test("そのあとの週は、月曜から日曜までの7日を並べ、開始の日の週から数えること")
        func laterWeekHasSevenDays() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 15), today: WeekRecapTests.day(10, 20)))

            #expect(
                recap.days.map(\.day)
                    == Array(WeekRecapTests.day(10, 12)...WeekRecapTests.day(10, 18)))
            #expect(recap.weekNumber == 3)
            #expect(recap.title == "10月12日〜18日")
        }

        @Test("月をまたぐ週は、終わりの日にも月を書くこと")
        func spansMonths() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 26), today: WeekRecapTests.day(11, 5)))

            #expect(recap.title == "10月26日〜11月1日")
        }

        @Test("今日を含む週は、今日までを並べ、途中と書くこと")
        func inProgressWeekEndsToday() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 14), today: WeekRecapTests.day(10, 14)))

            #expect(recap.isInProgress)
            #expect(
                recap.days.map(\.day)
                    == Array(WeekRecapTests.day(10, 12)...WeekRecapTests.day(10, 14)))
            #expect(recap.title == "10月12日〜18日（途中）")
        }

        @Test("目標を立てる前の週は、振り返りを出さないこと")
        func noRecapBeforeGoal() throws {
            #expect(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(9, 24), today: WeekRecapTests.day(10, 10)) == nil)
        }
    }

    @Suite("食べた量")
    struct Food {
        let recap: WeekRecap
        let secondWeekGuide: DailyGuide

        init() throws {
            let goal = try Goal.losing()
            let firstGuide = DailyGuide(
                id: UUID(), goalId: goal.id, expenditureEstimateId: UUID(),
                effectiveDay: WeekRecapTests.day(10, 1), energyKilocalories: 1900,
                proteinGrams: 120, fatGrams: 55, carbohydrateGrams: 230, limitHits: [])
            secondWeekGuide = DailyGuide(
                id: UUID(), goalId: goal.id, expenditureEstimateId: UUID(),
                effectiveDay: WeekRecapTests.day(10, 5), energyKilocalories: 1850,
                proteinGrams: 110, fatGrams: 50, carbohydrateGrams: 240, limitHits: [])
            // 10月5日の週。6日は記録が無く、7日は推定中
            recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 7),
                    goals: [goal], dailyGuides: [firstGuide, secondWeekGuide],
                    meals: [
                        try .fixture(
                            eatenAt: "2026-10-05T12:00:00+09:00", status: .estimated,
                            nutrients: [
                                .energyKcal: 1800, .proteinG: 100, .fatG: 50,
                                .carbohydrateG: 220,
                            ]),
                        try .fixture(
                            eatenAt: "2026-10-07T12:00:00+09:00", status: .estimated,
                            nutrients: [
                                .energyKcal: 1100, .proteinG: 60, .fatG: 30,
                                .carbohydrateG: 130,
                            ]),
                        try .fixture(
                            eatenAt: "2026-10-07T19:00:00+09:00", status: .estimated,
                            nutrients: [
                                .energyKcal: 1001, .proteinG: 59, .fatG: 21,
                                .carbohydrateG: 111,
                            ]),
                        try .fixture(eatenAt: "2026-10-07T21:00:00+09:00", status: .estimating),
                    ]))
        }

        @Test("その週に当たっていた1日の目安と比べること")
        func comparesWithGuideOfWeek() {
            #expect(recap.dailyGuide == secondWeekGuide)
        }

        @Test("平均は、食べた量が分かった日だけで出すこと")
        func averagesRecordedDays() throws {
            let average = try #require(recap.averageFood)

            #expect(average.energyKilocalories == 1951)
            #expect(average.proteinGrams == 110)
            #expect(average.fatGrams == 51)
            #expect(average.carbohydrateGrams == 231)
        }

        @Test("記録の無い日があれば、記録した日の数を添えること")
        func labelsRecordedDayCount() throws {
            #expect(try #require(recap.averageFood).label == "記録した 2 日の平均")
        }
    }

    @Suite("どの日も食べた量が分かったとき")
    struct EveryDayRecorded {
        @Test("平均にだけすること")
        func labelsPlainAverage() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 5),
                    meals: [
                        try .fixture(
                            eatenAt: "2026-10-05T12:00:00+09:00", status: .estimated,
                            nutrients: [.energyKcal: 1800])
                    ]))

            #expect(try #require(recap.averageFood).label == "平均")
        }
    }

    @Suite("食べた量が分かった日が無いとき")
    struct NoRecordedDay {
        @Test("平均を出さないこと")
        func hasNoAverage() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 6)))

            #expect(recap.averageFood == nil)
        }
    }

    /// 体重の傾向。日と値の組を、日の順に
    static func trend(_ days: [(CalendarDay, Double)]) -> WeightTrend {
        WeightTrend(days: days.map { WeightTrend.Day(day: $0.0, kilograms: $0.1) })
    }

    /// その日の朝 7 時（東京）の体重記録
    static func weightRecords(on days: [CalendarDay], kilograms: Double = 70.0) throws
        -> [WeightRecord]
    {
        try days.map {
            try .manual(kilograms, at: "\($0.yearMonthDay)T07:00:00+09:00", in: "Asia/Tokyo")
        }
    }

    @Suite("一番上のペース")
    struct TopLine {
        @Suite("間に合うとき")
        struct OnTrack {
            let recap: WeekRecap

            init() throws {
                recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 19), today: WeekRecapTests.day(10, 27),
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(10, 11), 71.0), (WeekRecapTests.day(10, 25), 70.0),
                        ]),
                        weightRecords: try WeekRecapTests.weightRecords(on: [
                            WeekRecapTests.day(10, 13), WeekRecapTests.day(10, 17),
                            WeekRecapTests.day(10, 21), WeekRecapTests.day(10, 25),
                        ])))
            }

            @Test("その週の日曜の実際の速さと、期限に届くのに要るペースを並べること")
            func showsActualAndRequiredPace() throws {
                let line = try #require(recap.topLine)

                #expect(line.headline == "間に合うペースです")
                #expect(
                    line.sentence
                        == "傾向で1週間に −0.5 kg。期限の12月24日に 68.0 kg へは、1週間に −0.2 kg で届きます。")
            }
        }

        @Suite("届かないとき")
        struct Behind {
            @Test("届かない量と、実際の速さと要るペースを並べること")
            func showsShortfall() throws {
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 19), today: WeekRecapTests.day(10, 27),
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(10, 11), 70.2), (WeekRecapTests.day(10, 25), 70.0),
                        ]),
                        weightRecords: try WeekRecapTests.weightRecords(on: [
                            WeekRecapTests.day(10, 13), WeekRecapTests.day(10, 17),
                            WeekRecapTests.day(10, 21), WeekRecapTests.day(10, 25),
                        ])))
                let line = try #require(recap.topLine)

                #expect(line.headline == "このままだと期限に 1.2 kg 届きません")
                #expect(
                    line.sentence
                        == "傾向で1週間に −0.1 kg。期限の12月24日に 68.0 kg へは、1週間に −0.2 kg で届きます。")
            }
        }

        @Suite("直近 14 日の体重の記録が少ないとき")
        struct FewWeightRecords {
            @Test("言い切らず、記録の日数を書くこと")
            func showsRecordDayCount() throws {
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 19), today: WeekRecapTests.day(10, 27),
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(10, 11), 71.0), (WeekRecapTests.day(10, 25), 70.0),
                        ]),
                        weightRecords: try WeekRecapTests.weightRecords(on: [
                            WeekRecapTests.day(10, 13), WeekRecapTests.day(10, 21),
                            WeekRecapTests.day(10, 25),
                        ])))
                let line = try #require(recap.topLine)

                #expect(line.headline == "まだ言い切れません")
                #expect(line.sentence == "直近 14 日の体重の記録が 3 日なので、傾向が定まっていません。")
            }
        }

        @Suite("目標を立てて 14 日たっていないとき")
        struct BeforeFourteenDays {
            @Test("いつペースを出すかを書くこと")
            func showsWhenPaceAppears() throws {
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 13),
                        weightTrend: WeekRecapTests.trend([(WeekRecapTests.day(10, 11), 71.0)])))
                let line = try #require(recap.topLine)

                #expect(line.headline == "まだ言い切れません")
                #expect(line.sentence == "目標を立てて 14 日たつと、間に合うペースかを出します。")
            }
        }

        @Suite("今週のとき")
        struct InProgress {
            @Test("日曜でなく今日で判定すること")
            func judgesToday() throws {
                // 日曜（10月18日）なら 17 日たっているが、今日（10月13日）は 12 日
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 13), today: WeekRecapTests.day(10, 13),
                        weightTrend: WeekRecapTests.trend([(WeekRecapTests.day(10, 13), 71.0)])))

                #expect(
                    try #require(recap.topLine).sentence
                        == "目標を立てて 14 日たつと、間に合うペースかを出します。")
            }
        }

        @Suite("達成した週のとき")
        struct Achieved {
            @Test("その週に起きたことを書くこと")
            func showsAchievement() throws {
                let losing = try Goal.losing()
                let goal = Goal(
                    id: losing.id, startedDay: losing.startedDay,
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction,
                    achievement: Goal.Achievement(
                        achievedDay: WeekRecapTests.day(11, 8),
                        judgedAt: try Date("2026-11-08T07:10:00+09:00", strategy: .iso8601),
                        timeZone: losing.timeZone),
                    deadlineConfirmation: nil, closure: nil)
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(11, 2), today: WeekRecapTests.day(11, 10),
                        goals: [goal],
                        weightTrend: WeekRecapTests.trend([(WeekRecapTests.day(11, 8), 67.9)])))
                let line = try #require(recap.topLine)

                #expect(line.headline == "目標に届いた週です")
                #expect(line.sentence == "11月8日に、体重の傾向が 68.0 kg に届きました。")
            }
        }

        @Suite("期限の日を含む週のとき")
        struct DeadlineWeek {
            @Test("期限の日の結果を書くこと")
            func showsDeadlineResult() throws {
                let losing = try Goal.losing()
                let goal = Goal(
                    id: losing.id, startedDay: losing.startedDay,
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction, achievement: nil,
                    deadlineConfirmation: Goal.DeadlineConfirmation(
                        deadlineWeightTrendKilograms: 68.4,
                        confirmedAt: try Date("2026-12-25T07:10:00+09:00", strategy: .iso8601),
                        timeZone: losing.timeZone),
                    closure: nil)
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(12, 21), today: WeekRecapTests.day(12, 29),
                        goals: [goal],
                        weightTrend: WeekRecapTests.trend([(WeekRecapTests.day(12, 27), 68.1)])))
                let line = try #require(recap.topLine)

                #expect(line.headline == "期限の週です")
                #expect(line.sentence == "12月24日の結果は、開始から −4.0 kg・目標まであと 0.4 kg でした。")
            }
        }

        @Suite("維持の目標のとき")
        struct Maintaining {
            static func recap(trend kilograms: Double) throws -> WeekRecap {
                // 10月20日に始めた、65.0 kg を保つ目標
                try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 26), today: WeekRecapTests.day(11, 3),
                        goals: [.maintaining()],
                        weightTrend: WeekRecapTests.trend([
                            (WeekRecapTests.day(11, 1), kilograms)
                        ])))
            }

            @Test("体重の傾向が幅に入っていれば、保てていると書くこと")
            func withinBand() throws {
                let line = try #require(try Self.recap(trend: 65.3).topLine)

                #expect(line.headline == "保てています")
                #expect(line.sentence == "体重の傾向は 65.3 kg で、65.0 kg を保つ幅（±0.7 kg）に入っています。")
            }

            @Test("体重の傾向が幅から外れていれば、外れていると書くこと")
            func outsideBand() throws {
                let line = try #require(try Self.recap(trend: 65.8).topLine)

                #expect(line.headline == "幅から外れています")
                #expect(line.sentence == "体重の傾向は 65.8 kg で、65.0 kg を保つ幅（±0.7 kg）から外れています。")
            }
        }
    }
}
