import Foundation
import NuToriCore
import Testing

/// 10月1日（木）に立てた、12月24日（木）までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）などの、体重の画面の目標までの道のり
@Suite("体重の画面の目標までの道のり")
struct WeightGoalPathTests {
    static func path(
        today: CalendarDay, goals: [Goal], weightTrend: WeightTrend? = nil,
        weightRecords: [WeightRecord] = []
    ) -> WeightGoalPath? {
        let records = GoalRecords(
            goals: goals, dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
            weightTrend: weightTrend, weightRecords: weightRecords)
        let current = CurrentGoal(today: today, goals: goals, dailyGuides: [])
        return WeightGoalPath(
            status: GoalStatus(currentGoal: current?.goal, goals: goals), today: today,
            records: records)
    }

    @Test("目標がないときは、道のりを出さないこと")
    func noGoal() {
        #expect(Self.path(today: DaySummaryGoalTests.day(11, 10), goals: []) == nil)
    }

    @Suite("減量の目標が進行中のとき")
    struct LosingInProgress {
        @Test("あと何 kg と期限まであと何日の行、最近の傾向と間に合うペースかの注記を出すこと")
        func showsRowsAndPace() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(11, 10), goals: [try .losing()],
                    weightTrend: DaySummaryGoalTests.trend([
                        (DaySummaryGoalTests.day(10, 27), 71.8),
                        (DaySummaryGoalTests.day(11, 10), 70.8),
                    ]),
                    weightRecords: try DaySummaryGoalTests.morningRecords([3, 6, 8, 10])))
            #expect(
                path.rows == [
                    .init(label: "減量", value: "68.0 kg まで あと 2.8 kg"),
                    .init(label: "期限", value: "12月24日 あと 45 日"),
                ])
            #expect(path.note == "最近の傾向は −0.5 kg／週で、期限に間に合うペースです。")
        }

        @Test("期限に届かないペースなら、届かない量を注記に書くこと")
        func showsShortfall() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(11, 10), goals: [try .losing()],
                    weightTrend: DaySummaryGoalTests.trend([
                        (DaySummaryGoalTests.day(10, 27), 71.0),
                        (DaySummaryGoalTests.day(11, 10), 70.8),
                    ]),
                    weightRecords: try DaySummaryGoalTests.morningRecords([3, 6, 8, 10])))
            #expect(path.note == "このままだと期限に 2.2 kg 届きません。")
        }

        @Test("体重の記録が少なければ、ペースを言い切らないこと")
        func showsInconclusive() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(11, 10), goals: [try .losing()],
                    weightTrend: DaySummaryGoalTests.trend([
                        (DaySummaryGoalTests.day(10, 27), 71.8),
                        (DaySummaryGoalTests.day(11, 10), 70.8),
                    ]),
                    weightRecords: try DaySummaryGoalTests.morningRecords([10])))
            #expect(path.note == "体重の記録が少なく、ペースはまだ言い切れません。")
        }
    }

    @Suite("維持の目標のとき")
    struct Maintaining {
        @Test("保つ体重の行と、保つ幅に入っているかの注記を出すこと")
        func showsBand() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(11, 10), goals: [try .maintaining()],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(11, 9), 65.4)])
                ))
            #expect(path.rows == [.init(label: "維持", value: "65.0 kg を保つ")])
            #expect(path.note == "体重の傾向は保つ幅に入っています。")
        }
    }

    @Suite("達成・期限・期限後の維持のとき")
    struct Settled {
        @Test("期限より前に達成したら、達成したことを1行で出し、注記を出さないこと")
        func achieved() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(12, 12),
                    goals: [
                        try GoalOverviewTests.losing(achievedOn: DaySummaryGoalTests.day(12, 10))
                    ]))
            #expect(path.rows == [.init(label: "減量", value: "68.0 kg を達成しました")])
            #expect(path.note == nil)
        }

        @Test("期限が来たら、期限を迎えたことと目標まであと何 kg だったかを出すこと")
        func deadlineReached() throws {
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(12, 26),
                    goals: [try GoalOverviewTests.losing(confirmedTrend: 68.4)]))
            #expect(path.rows == [.init(label: "減量", value: "期限を迎えました・あと 0.4 kg")])
            #expect(path.note == nil)
        }

        @Test("期限後の維持なら、保つ体重と保てているかを出すこと")
        func maintainingAfterDeadline() throws {
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
            let path = try #require(
                WeightGoalPathTests.path(
                    today: DaySummaryGoalTests.day(12, 30), goals: [previous, maintenance],
                    weightTrend: DaySummaryGoalTests.trend([(DaySummaryGoalTests.day(12, 30), 68.4)]
                    )
                ))
            #expect(path.rows == [.init(label: "維持", value: "68.3 kg を保つ・保てています")])
            #expect(path.note == nil)
        }
    }
}
