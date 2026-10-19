import Foundation
import NuToriCore
import Testing

/// 10月1日（木）に立てた、12月24日（木）までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）などの日のまとめ
@Suite("日のまとめの目標")
struct DaySummaryGoalTests {
    static func day(_ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: 2026, month: month, day: day)
    }

    static func summary(
        day: CalendarDay, today: CalendarDay, goals: [Goal], weightTrend: WeightTrend? = nil,
        weightRecords: [WeightRecord] = []
    ) -> DaySummaryGoal? {
        DaySummaryGoal(
            day: day, today: today,
            records: GoalRecords(
                goals: goals, dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                weightTrend: weightTrend, weightRecords: weightRecords))
    }

    static func trend(_ days: [(CalendarDay, Double)]) -> WeightTrend {
        WeightTrend(days: days.map { WeightTrend.Day(day: $0.0, kilograms: $0.1) })
    }

    /// 11月10日までの 14 日に4日記録し、傾向が 10月27日の 71.8 kg から 11月10日の 70.8 kg へ下がった（1週間に −0.5 kg）
    static func morningRecords(_ days: [Int], kilograms: Double = 70.8) throws -> [WeightRecord] {
        try days.map { day in
            try WeightRecord.manual(
                kilograms, at: "2026-11-\(String(format: "%02d", day))T07:00:00+09:00",
                in: "Asia/Tokyo")
        }
    }

    @Suite("減量の目標が進行中のとき")
    struct LosingInProgress {
        @Test("あと何 kg、あと何日、間に合うペースかを1行に書き、次の目標の行を足さないこと")
        func showsProgressAndPace() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(11, 10), today: DaySummaryGoalTests.day(11, 10),
                    goals: [try .losing()],
                    weightTrend: DaySummaryGoalTests.trend([
                        (DaySummaryGoalTests.day(10, 27), 71.8),
                        (DaySummaryGoalTests.day(11, 10), 70.8),
                    ]),
                    weightRecords: try DaySummaryGoalTests.morningRecords([3, 6, 8, 10])))
            #expect(summary.detail == "あと 2.8 kg・あと 45 日・間に合うペース")
            #expect(summary.nextGoal == nil)
        }
    }

    @Suite("減量の目標が期限に届かないペースのとき")
    struct LosingBehind {
        @Test("期限に何 kg 届かないかを書くこと")
        func showsShortfall() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(11, 10), today: DaySummaryGoalTests.day(11, 10),
                    goals: [try .losing()],
                    weightTrend: DaySummaryGoalTests.trend([
                        (DaySummaryGoalTests.day(10, 27), 71.0),
                        (DaySummaryGoalTests.day(11, 10), 70.8),
                    ]),
                    weightRecords: try DaySummaryGoalTests.morningRecords([3, 6, 8, 10])))
            #expect(summary.detail == "あと 2.8 kg・あと 45 日・期限に 2.2 kg 届かない")
        }
    }

    @Suite("維持の目標のとき")
    struct Maintaining {
        @Test("保つ体重と、保てているかを書くこと")
        func showsBand() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(11, 10), today: DaySummaryGoalTests.day(11, 10),
                    goals: [try .maintaining()],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(11, 9), 65.4)])
                ))
            #expect(summary.detail == "65.0 kg を保つ・保てています")
            #expect(summary.nextGoal == nil)
        }
    }

    @Suite("期限より前に達成したとき")
    struct Achieved {
        @Test("達成したことと、次の目標を選ぶ行を出すこと")
        func showsAchievement() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 12), today: DaySummaryGoalTests.day(12, 12),
                    goals: [
                        try GoalOverviewTests.losing(achievedOn: DaySummaryGoalTests.day(12, 10))
                    ],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(12, 12), 67.9)]
                    )
                ))
            #expect(summary.detail == "68.0 kg を達成しました")
            #expect(summary.nextGoal == .choose)
        }

        @Test("達成した日より前の日のまとめは、その日の進行中の形で書き、次の目標の行を足さないこと")
        func showsPastDayInProgress() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 9), today: DaySummaryGoalTests.day(12, 12),
                    goals: [
                        try GoalOverviewTests.losing(achievedOn: DaySummaryGoalTests.day(12, 10))
                    ],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(12, 9), 68.1)])
                ))
            #expect(summary.detail?.hasPrefix("あと 0.1 kg・あと 16 日") == true)
            #expect(summary.nextGoal == nil)
        }
    }

    @Suite("期限が来たとき")
    struct DeadlineReached {
        @Test("期限を迎えたことと目標まであと何 kg だったか、次の目標を選ぶ行を出すこと")
        func showsResult() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 26), today: DaySummaryGoalTests.day(12, 26),
                    goals: [try GoalOverviewTests.losing(confirmedTrend: 68.4)]))
            #expect(summary.detail == "期限を迎えました・あと 0.4 kg")
            #expect(summary.nextGoal == .choose)
        }

        @Test("期限のあとに達成したら、達成した日を書くこと")
        func showsLateAchievement() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 28), today: DaySummaryGoalTests.day(12, 28),
                    goals: [
                        try GoalOverviewTests.losing(
                            achievedOn: DaySummaryGoalTests.day(12, 27), confirmedTrend: 68.4)
                    ]))
            #expect(summary.detail == "12月27日に 68.0 kg を達成しました")
            #expect(summary.nextGoal == .choose)
        }

        @Test("期限の日のまとめは、確定する前の形で書くこと")
        func showsDeadlineDayInProgress() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 24), today: DaySummaryGoalTests.day(12, 26),
                    goals: [try GoalOverviewTests.losing(confirmedTrend: 68.4)],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(12, 24), 68.4)]
                    )
                ))
            #expect(summary.detail == "あと 0.4 kg・あと 1 日")
            #expect(summary.nextGoal == nil)
        }
    }

    @Suite("期限後の維持のとき")
    struct MaintainingAfterDeadline {
        let goals: [Goal]

        init() throws {
            let maintenanceId = UUID()
            let previous = try GoalOverviewTests.losing(
                confirmedTrend: 68.4,
                closure: Goal.Closure(
                    endedDay: DaySummaryGoalTests.day(12, 28), nextGoalId: maintenanceId,
                    endReason: .movedToMaintenance))
            let maintenance = Goal(
                id: maintenanceId, startedDay: DaySummaryGoalTests.day(12, 28),
                startingWeightTrendKilograms: 68.3, targetWeightKilograms: 68.3,
                decidedAt: try Date("2026-12-28T07:00:00+09:00", strategy: .iso8601),
                timeZone: previous.timeZone, direction: .maintain, achievement: nil,
                deadlineConfirmation: nil, closure: nil)
            goals = [previous, maintenance]
        }

        @Test("保つ体重と保てているか、次の目標を立てる行を出すこと")
        func showsMaintenance() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 30), today: DaySummaryGoalTests.day(12, 30),
                    goals: goals,
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(12, 30), 68.4)]
                    )
                ))
            #expect(summary.detail == "68.3 kg を保つ・保てています")
            #expect(summary.nextGoal == .set)
        }

        @Test("期限のあと維持に移る前の日のまとめは、前の目標の形で書き、閉じた目標の次の目標の行を足さないこと")
        func showsPreviousGoalOnPastDay() throws {
            let summary = try #require(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(12, 26), today: DaySummaryGoalTests.day(12, 30),
                    goals: goals))
            #expect(summary.detail == "期限を迎えました・あと 0.4 kg")
            #expect(summary.nextGoal == nil)
        }
    }

    @Suite("目標を立てる前の日")
    struct BeforeGoal {
        @Test("目標の行を出さないこと")
        func hasNoGoalRow() throws {
            #expect(
                DaySummaryGoalTests.summary(
                    day: DaySummaryGoalTests.day(9, 30), today: DaySummaryGoalTests.day(10, 2),
                    goals: [try .losing()]) == nil)
        }
    }
}
