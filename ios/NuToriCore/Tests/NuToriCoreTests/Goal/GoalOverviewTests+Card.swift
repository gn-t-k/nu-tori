import Foundation
import NuToriCore
import Testing

extension GoalOverviewTests {
    @Suite("今の目標のカード")
    struct Card {
        @Suite("減量の目標が進行中のとき")
        struct LosingInProgress {
            let card: GoalOverview.Card

            init() throws {
                let records = try [10, 3, 6, 8].map { day in
                    try WeightRecord.manual(
                        70.8, at: "2026-11-\(String(format: "%02d", day))T07:00:00+09:00",
                        in: "Asia/Tokyo")
                }
                card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 10), goals: [try .losing()],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(10, 27), 71.8),
                            (GoalOverviewTests.day(11, 10), 70.8),
                        ]),
                        weightRecords: records)
                ).card
            }

            @Test("向きと期間、あと何 kg、あと何日、間に合うペースかを出すこと")
            func showsProgress() {
                #expect(card.summary == "減量 10月1日〜12月24日")
                #expect(card.title == "68.0 kg まで あと 2.8 kg")
                #expect(card.detail == "あと 45 日・間に合うペースです")
            }

            @Test("目標を切り替えられること")
            func offersSwitch() {
                #expect(card.action == .switchGoal)
                #expect(card.lateAchievement == nil)
            }

            @Test("切り替えるあいだ、今の目標が続くことを書くこと")
            func notesContinuing() {
                #expect(
                    card.continuingNote
                        == "今の目標（減量・12月24日までに 68.0 kg）は、新しい目標が決まるまで続きます。")
            }
        }

        @Suite("目標を立てて 14 日たっていないとき")
        struct BeforeFourteenDays {
            @Test("いつペースが出るかを書くこと")
            func showsWhenPaceAppears() throws {
                let card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(10, 10), goals: [try .losing()],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(10, 10), 71.9)
                        ]))
                ).card

                #expect(card.detail == "あと 76 日・間に合うかは、目標を立てて 14 日たつと出ます")
            }
        }

        @Suite("維持の目標が進行中のとき")
        struct MaintainingInProgress {
            @Test("保つ体重と、今の傾向が幅に入っているかを出すこと")
            func showsBand() throws {
                let card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 3), goals: [try .maintaining()],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(11, 3), 65.3)
                        ]))
                ).card

                #expect(card.summary == "維持 10月20日から・期限なし")
                #expect(card.title == "65.0 kg を保つ")
                #expect(card.detail == "傾向 65.3 kg・保てています")
                #expect(card.action == .switchGoal)
                #expect(card.continuingNote == "今の目標（維持・65.0 kg を保つ）は、新しい目標が決まるまで続きます。")
            }
        }

        @Suite("期限より前に達成したとき")
        struct AchievedBeforeDeadline {
            let card: GoalOverview.Card

            init() throws {
                card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(11, 10),
                        goals: [
                            try GoalOverviewTests.losing(achievedOn: GoalOverviewTests.day(11, 8))
                        ],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(11, 10), 67.8)
                        ]))
                ).card
            }

            @Test("達成したことと、期限より何日早かったかを出すこと")
            func showsAchievement() {
                #expect(card.summary == "減量 10月1日〜12月24日")
                #expect(card.title == "68.0 kg を達成しました")
                #expect(card.detail == "期限より 46 日早い・傾向 67.8 kg。次の目標を選ぶまで、今の目標を続けます。")
            }

            @Test("次の目標を選べること")
            func offersNextGoal() {
                #expect(card.action == .chooseNextGoal)
            }
        }

        @Suite("期限が来たとき")
        struct DeadlineReached {
            let card: GoalOverview.Card

            init() throws {
                card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(12, 26),
                        goals: [try GoalOverviewTests.losing(confirmedTrend: 68.4)])
                ).card
            }

            @Test("期限の日の結果と、選ばなければいつから維持になるかを出すこと")
            func showsResult() {
                #expect(card.title == "68.4 kg で期限を迎えました")
                #expect(
                    card.detail
                        == "開始から −4.0 kg・目標まであと 0.4 kg。選ばなければ、12月28日（月）から今の体重を保つ目標で続けます。")
                #expect(card.lateAchievement == nil)
            }

            @Test("次の目標を選べること")
            func offersNextGoal() {
                #expect(card.action == .chooseNextGoal)
            }
        }

        @Suite("期限のあとに達成したとき")
        struct AchievedAfterDeadline {
            @Test("期限の日の結果に、達成したことを足すこと")
            func addsAchievement() throws {
                let card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(12, 27),
                        goals: [
                            try GoalOverviewTests.losing(
                                achievedOn: GoalOverviewTests.day(12, 26), confirmedTrend: 68.4)
                        ])
                ).card

                #expect(card.title == "68.4 kg で期限を迎えました")
                #expect(card.lateAchievement == "12月26日に 68.0 kg を達成しました")
            }
        }

        @Suite("期限後の維持に移ったとき")
        struct MaintainingAfterDeadline {
            let card: GoalOverview.Card

            init() throws {
                let maintenanceId = UUID()
                let previous = try GoalOverviewTests.losing(
                    confirmedTrend: 68.4,
                    closure: Goal.Closure(
                        endedDay: GoalOverviewTests.day(12, 28), nextGoalId: maintenanceId,
                        endReason: .movedToMaintenance))
                let maintenance = try Goal.maintaining(
                    id: maintenanceId, startedOn: GoalOverviewTests.day(12, 28),
                    kilograms: 68.3, decidedAt: "2026-12-28T07:00:00+09:00")
                card = try #require(
                    GoalOverviewTests.overview(
                        today: GoalOverviewTests.day(12, 30), goals: [previous, maintenance],
                        weightTrend: GoalOverviewTests.trend([
                            (GoalOverviewTests.day(12, 30), 68.4)
                        ]))
                ).card
            }

            @Test("保つ体重と、期限のあと選ばなかったので維持に移ったことを出すこと")
            func showsMaintenance() {
                #expect(card.summary == "維持 12月28日から・期限なし")
                #expect(card.title == "68.3 kg を保つ")
                #expect(
                    card.detail
                        == "傾向 68.4 kg・保てています。12月24日の期限のあと次の目標を選ばなかったので、68.3 kg を保つ目標で続けています。")
            }

            @Test("次の目標を立てられること")
            func offersNewGoal() {
                #expect(card.action == .setNextGoal)
            }
        }
    }
}
