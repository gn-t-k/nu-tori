import Foundation
import NuToriCore
import Testing

extension GoalOverviewTests {
    @Suite("推定消費カロリーと1日の目安")
    struct EnergyChart {
        /// 当てる始まりの日と推定消費カロリー・1日の目安の kcal の組から、`goal` の記録を作る
        static func records(_ goal: Goal, _ values: [(CalendarDay, Int, Int)]) -> (
            [ExpenditureEstimate], [DailyGuide]
        ) {
            let estimates = values.map {
                ExpenditureEstimate(
                    id: UUID(), effectiveDay: $0.0, expenditureKilocalories: $0.1,
                    estimatedAt: goal.decidedAt, initialSource: nil)
            }
            let guides = zip(values, estimates).map { value, estimate in
                DailyGuide(
                    id: UUID(), goalId: goal.id, expenditureEstimateId: estimate.id,
                    effectiveDay: value.0, energyKilocalories: value.2, proteinGrams: 110,
                    fatGrams: 50, carbohydrateGrams: 240, limitHits: [])
            }
            return (estimates, guides)
        }

        @Suite("見直した点が3つたまったとき")
        struct Drawn {
            let chart: GoalOverview.EnergyChart

            init() throws {
                let goal = try Goal.losing()
                let (estimates, guides) = EnergyChart.records(
                    goal,
                    [
                        (GoalOverviewTests.day(10, 1), 2190, 1880),
                        (GoalOverviewTests.day(10, 12), 2160, 1860),
                        (GoalOverviewTests.day(10, 19), 2140, 1850),
                    ])
                chart = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(10, 28), goals: [goal], dailyGuides: guides,
                        expenditureEstimates: estimates,
                        weeklyReviews: [
                            WeeklyReview(
                                id: UUID(), effectiveDay: GoalOverviewTests.day(10, 26),
                                reviewedAt: try Date(
                                    "2026-10-26T07:00:00+09:00", strategy: .iso8601),
                                timeZone: goal.timeZone,
                                outcome: .deferred(reason: .fewMealRecords, goalId: goal.id))
                        ])?.energyChart)
            }

            @Test("当てる始まりの日ごとの点と、見送った週の印で、開始の日から期限の日までを描くこと")
            func drawsPointsAndDeferrals() {
                #expect(
                    chart.graph
                        == GoalOverview.EnergyChart.Graph(
                            days: GoalOverviewTests.day(10, 1)...GoalOverviewTests.day(12, 24),
                            points: [
                                .init(
                                    day: GoalOverviewTests.day(10, 1),
                                    expenditureKilocalories: 2190, dailyGuideKilocalories: 1880),
                                .init(
                                    day: GoalOverviewTests.day(10, 12),
                                    expenditureKilocalories: 2160, dailyGuideKilocalories: 1860),
                                .init(
                                    day: GoalOverviewTests.day(10, 19),
                                    expenditureKilocalories: 2140, dailyGuideKilocalories: 1850),
                            ],
                            deferredDays: [GoalOverviewTests.day(10, 26)]))
            }

            @Test("グラフの上にも、今の値の棒を出すこと")
            func keepsBars() {
                #expect(
                    chart.bars
                        == GoalOverview.EnergyChart.Bars(
                            expenditureKilocalories: 2140, dailyGuideKilocalories: 1850))
            }
        }

        @Suite("見直した点が3つ未満のとき")
        struct Bars {
            let chart: GoalOverview.EnergyChart

            init() throws {
                let goal = try Goal.losing()
                let (estimates, guides) = EnergyChart.records(
                    goal,
                    [
                        (GoalOverviewTests.day(10, 1), 2190, 1880),
                        (GoalOverviewTests.day(10, 5), 2250, 1900),
                    ])
                chart = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(10, 10), goals: [goal], dailyGuides: guides,
                        expenditureEstimates: estimates)?.energyChart)
            }

            @Test("グラフを描かないこと")
            func hidesGraph() {
                #expect(chart.graph == nil)
            }

            @Test("今の推定消費カロリーと1日の目安の棒と、減らす分を出すこと")
            func showsBarsWithDeficit() {
                #expect(
                    chart.bars
                        == GoalOverview.EnergyChart.Bars(
                            expenditureKilocalories: 2250, dailyGuideKilocalories: 1900))
                #expect(chart.bars.gap == "減らす分 −350 kcal")
            }

            @Suite("今日より後に当てる1日の目安が届いているとき")
            struct FutureGuide {
                let chart: GoalOverview.EnergyChart

                init() throws {
                    let goal = try Goal.losing()
                    let (estimates, guides) = EnergyChart.records(
                        goal,
                        [
                            (GoalOverviewTests.day(10, 1), 2190, 1880),
                            (GoalOverviewTests.day(10, 12), 2250, 1900),
                        ])
                    chart = try #require(
                        GoalOverviewTests.overview(
                            today: GoalOverviewTests.day(10, 10), goals: [goal],
                            dailyGuides: guides,
                            expenditureEstimates: estimates)?.energyChart)
                }

                @Test("今日に当たっている1日の目安で棒を出すこと")
                func usesTodaysGuide() {
                    #expect(
                        chart.bars
                            == GoalOverview.EnergyChart.Bars(
                                expenditureKilocalories: 2190, dailyGuideKilocalories: 1880))
                }
            }

            @Suite("1日の目安が推定消費カロリーより多いとき")
            struct Surplus {
                let bars = GoalOverview.EnergyChart.Bars(
                    expenditureKilocalories: 2600, dailyGuideKilocalories: 2950)

                @Test("足す分を出すこと")
                func showsSurplus() {
                    #expect(bars.gap == "足す分 +350 kcal")
                }
            }

            @Suite("1日の目安が推定消費カロリーと同じとき")
            struct Same {
                let bars = GoalOverview.EnergyChart.Bars(
                    expenditureKilocalories: 2600, dailyGuideKilocalories: 2600)

                @Test("差を出さないこと")
                func hidesGap() {
                    #expect(bars.gap == nil)
                }
            }
        }

        @Suite("期限より前に達成したとき")
        struct Achieved {
            @Test("出さないこと")
            func hidesChart() throws {
                let goal = try GoalOverviewTests.losing(achievedOn: GoalOverviewTests.day(11, 8))
                let (estimates, guides) = EnergyChart.records(
                    goal, [(GoalOverviewTests.day(10, 1), 2190, 1880)])

                #expect(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 10), goals: [goal], dailyGuides: guides,
                        expenditureEstimates: estimates)?.energyChart == nil)
            }
        }
    }

    @Suite("体重の傾向")
    struct WeightChart {
        @Test("減量の目標は、開始の日から期限の日までの傾向を出すこと")
        func spansGoalPeriod() throws {
            let chart = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(11, 10), goals: [try .losing()],
                    weightTrend: GoalOverviewTests.trend([
                        (GoalOverviewTests.day(9, 30), 72.5), (GoalOverviewTests.day(10, 1), 72.4),
                        (GoalOverviewTests.day(11, 10), 70.8),
                    ]))
            ).weightChart

            #expect(chart.title == "体重の傾向")
            #expect(chart.days == GoalOverviewTests.day(10, 1)...GoalOverviewTests.day(12, 24))
            #expect(
                chart.trend == [
                    WeightTrend.Day(day: GoalOverviewTests.day(10, 1), kilograms: 72.4),
                    WeightTrend.Day(day: GoalOverviewTests.day(11, 10), kilograms: 70.8),
                ])
        }

        @Test("維持の目標は、開始の日から今日までを出すこと")
        func maintainingSpansToToday() throws {
            let chart = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(11, 3), goals: [try .maintaining()])
            ).weightChart

            #expect(chart.days == GoalOverviewTests.day(10, 20)...GoalOverviewTests.day(11, 3))
        }

        @Suite("減量の目標が進行中のとき")
        struct LosingProgress {
            let chart: GoalOverview.WeightChart

            init() throws {
                let records = try [10, 3, 6, 8].map { day in
                    try WeightRecord.manual(
                        70.8, at: "2026-11-\(String(format: "%02d", day))T07:00:00+09:00",
                        in: "Asia/Tokyo")
                }
                chart = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 10), goals: [try .losing()],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(10, 27), 71.8),
                            (GoalOverviewTests.day(11, 10), 70.8),
                        ]),
                        weightRecords: records)
                ).weightChart
            }

            @Test("あと何 kg、あと何日、間に合うペースかを出すこと")
            func showsProgress() {
                #expect(
                    chart.progress
                        == GoalOverview.WeightChart.Progress(
                            remainingKilograms: "あと 2.8 kg", remainingDays: "あと 45 日",
                            pace: "間に合うペースです"))
            }
        }

        @Suite("目標を立てて 14 日たっていないとき")
        struct BeforeFourteenDays {
            let chart: GoalOverview.WeightChart

            init() throws {
                chart = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(10, 10), goals: [try .losing()],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(10, 10), 71.9)
                        ]))
                ).weightChart
            }

            @Test("あと何日と、いつペースが出るかを書くこと")
            func showsWhenPaceAppears() {
                #expect(chart.progress?.remainingDays == "あと 76 日")
                #expect(chart.progress?.pace == "間に合うかは、目標を立てて 14 日たつと出ます")
            }
        }

        @Suite("維持の目標が進行中のとき")
        struct MaintainingProgress {
            let chart: GoalOverview.WeightChart

            init() throws {
                chart = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 3), goals: [try .maintaining()])
                ).weightChart
            }

            @Test("進み具合を出さないこと")
            func hidesProgress() {
                #expect(chart.progress == nil)
            }
        }

        @Test("期限が来たときは、体重の歩みにすること")
        func namesJourneyAfterDeadline() throws {
            let chart = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(12, 26),
                    goals: [try GoalOverviewTests.losing(confirmedTrend: 68.4)])
            ).weightChart

            #expect(chart.title == "体重の歩み")
        }
    }

    @Suite("週の振り返りへの1行")
    struct RecapWeek {
        @Test("いちばん新しく見直した週を開くこと")
        func opensLatestReviewedWeek() throws {
            let goal = try Goal.losing()
            let overview = GoalOverviewTests.overview(
                today: GoalOverviewTests.day(10, 21), goals: [goal],
                weeklyReviews: [
                    WeeklyReview(
                        id: UUID(), effectiveDay: GoalOverviewTests.day(10, 19),
                        reviewedAt: try Date("2026-10-19T07:00:00+09:00", strategy: .iso8601),
                        timeZone: goal.timeZone,
                        outcome: .deferred(reason: .noWeight, goalId: goal.id))
                ])

            #expect(overview?.recapWeekMonday == GoalOverviewTests.day(10, 12))
        }

        @Test("まだ見直した週が無ければ、今週を開くこと")
        func opensThisWeek() throws {
            let overview = GoalOverviewTests.overview(
                today: GoalOverviewTests.day(10, 3), goals: [try .losing()])

            #expect(overview?.recapWeekMonday == GoalOverviewTests.day(9, 28))
        }
    }

    @Suite("過去の目標")
    struct PastGoals {
        let pastGoals: [GoalOverview.PastGoal]

        init() throws {
            // 9月1日からの維持 → 10月1日からの減量 → 11月2日に2回立て直して、11月2日からの維持
            let losing = try Goal.losing()
            let zeroDayId = UUID()
            let currentId = UUID()
            let earlier = Goal(
                id: UUID(), startedDay: GoalOverviewTests.day(9, 1),
                startingWeightTrendKilograms: 73.0, targetWeightKilograms: 73.0,
                decidedAt: try Date("2026-09-01T08:00:00+09:00", strategy: .iso8601),
                timeZone: losing.timeZone, direction: .maintain, achievement: nil,
                deadlineConfirmation: nil,
                closure: Goal.Closure(
                    endedDay: GoalOverviewTests.day(10, 1), nextGoalId: losing.id,
                    endReason: .switched))
            let switched = Goal(
                id: losing.id, startedDay: losing.startedDay,
                startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                targetWeightKilograms: losing.targetWeightKilograms, decidedAt: losing.decidedAt,
                timeZone: losing.timeZone, direction: losing.direction, achievement: nil,
                deadlineConfirmation: nil,
                closure: Goal.Closure(
                    endedDay: GoalOverviewTests.day(11, 2), nextGoalId: zeroDayId,
                    endReason: .switched))
            let zeroDay = Goal(
                id: zeroDayId, startedDay: GoalOverviewTests.day(11, 2),
                startingWeightTrendKilograms: 70.4, targetWeightKilograms: 66.0,
                decidedAt: try Date("2026-11-02T08:00:00+09:00", strategy: .iso8601),
                timeZone: losing.timeZone, direction: losing.direction, achievement: nil,
                deadlineConfirmation: nil,
                closure: Goal.Closure(
                    endedDay: GoalOverviewTests.day(11, 2), nextGoalId: currentId,
                    endReason: .switched))
            let current = Goal(
                id: currentId, startedDay: GoalOverviewTests.day(11, 2),
                startingWeightTrendKilograms: 70.4, targetWeightKilograms: 70.4,
                decidedAt: try Date("2026-11-02T09:00:00+09:00", strategy: .iso8601),
                timeZone: losing.timeZone, direction: .maintain, achievement: nil,
                deadlineConfirmation: nil, closure: nil)
            pastGoals = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(11, 10),
                    goals: [earlier, switched, zeroDay, current],
                    weightTrend: GoalOverviewTests.trend([
                        (GoalOverviewTests.day(9, 1), 73.0), (GoalOverviewTests.day(10, 1), 72.4),
                        (GoalOverviewTests.day(11, 1), 70.6), (GoalOverviewTests.day(11, 2), 70.4),
                    ]))
            ).pastGoals
        }

        @Test("0日の目標を除き、新しい順に並べること")
        func listsNewestFirstWithoutZeroDay() {
            #expect(pastGoals.map(\.summary) == ["減量 10月1日〜11月1日", "維持 9月1日〜30日"])
        }

        @Test("開始の日から終わった日までの体重の傾向の変化を結果にすること")
        func showsChangeUntilEnded() {
            #expect(pastGoals.first?.weightsText == "72.4 → 70.4 kg")
            #expect(pastGoals.first?.resultText == "−2.0 kg")
        }
    }

    @Suite("期限の日より後に閉じた過去の目標")
    struct PastGoalAfterDeadline {
        @Test("期限の日の結果を結果にすること")
        func showsDeadlineResult() throws {
            let maintenanceId = UUID()
            let previous = try GoalOverviewTests.losing(
                confirmedTrend: 68.4,
                closure: Goal.Closure(
                    endedDay: GoalOverviewTests.day(12, 28), nextGoalId: maintenanceId,
                    endReason: .movedToMaintenance))
            let maintenance = Goal(
                id: maintenanceId, startedDay: GoalOverviewTests.day(12, 28),
                startingWeightTrendKilograms: 68.3, targetWeightKilograms: 68.3,
                decidedAt: try Date("2026-12-28T07:00:00+09:00", strategy: .iso8601),
                timeZone: previous.timeZone, direction: .maintain, achievement: nil,
                deadlineConfirmation: nil, closure: nil)
            let past = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(12, 30), goals: [previous, maintenance],
                    weightTrend: GoalOverviewTests.trend([(GoalOverviewTests.day(12, 28), 68.3)]))?
                    .pastGoals.first)

            #expect(past.summary == "減量 10月1日〜12月24日")
            #expect(past.weightsText == "72.4 → 68.4 kg")
            #expect(past.resultText == "−4.0 kg")
        }
    }
}
