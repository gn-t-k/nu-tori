import Foundation
import NuToriCore
import Testing

@Suite("左上の目標の入口")
struct GoalLinkCapsuleTests {
    static let today = CalendarDay(year: 2026, month: 11, day: 2)

    @Suite("進行中の減量のとき")
    struct LosingInProgress {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .inProgress(try Goal.losing()), today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(
                        GoalLinkCapsuleTests.today.advanced(by: -1), kilograms: [70.6, 70.2])))
        }

        @Test("今日の体重の傾向から残りの kg と進み具合を出すこと")
        func showsRemainingAndProgress() {
            #expect(entry.text == "あと 2.2 kg")
            #expect(entry.progressPercent == 50)
        }
    }

    @Suite("進行中の増量のとき")
    struct GainingInProgress {
        let entry: GoalLinkCapsule

        init() throws {
            let losing = try Goal.losing()
            let goal = Goal(
                id: UUID(), startedDay: losing.startedDay, startingWeightTrendKilograms: 60.0,
                targetWeightKilograms: 64.0, decidedAt: losing.decidedAt,
                timeZone: losing.timeZone,
                direction: .gain(
                    Goal.WeightChange(
                        deadlineDay: CalendarDay(year: 2026, month: 12, day: 24),
                        pacePlan: .standard)),
                achievement: nil, deadlineConfirmation: nil, closure: nil)
            entry = try #require(
                GoalLinkCapsule(
                    status: .inProgress(goal), today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(GoalLinkCapsuleTests.today, kilograms: [61.0])))
        }

        @Test("開始の体重から目標体重へ進んだ分を進み具合にすること")
        func showsProgressFromStart() {
            #expect(entry.text == "あと 3.0 kg")
            #expect(entry.progressPercent == 25)
        }
    }

    @Suite("目標体重を越えたとき")
    struct Overshot {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .inProgress(try Goal.losing()), today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(GoalLinkCapsuleTests.today, kilograms: [67.5])))
        }

        @Test("残りを 0 kg、輪を一周で止めること")
        func stopsAtFullCircle() {
            #expect(entry.text == "あと 0.0 kg")
            #expect(entry.progressPercent == 100)
        }
    }

    @Suite("今日以前の体重の傾向がまだ届いていないとき")
    struct NoWeightTrend {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .inProgress(try Goal.losing()), today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(
                        GoalLinkCapsuleTests.today.advanced(by: 1), kilograms: [70.0])))
        }

        @Test("開始の体重から数えること")
        func countsFromStartingWeight() {
            #expect(entry.text == "あと 4.4 kg")
            #expect(entry.progressPercent == 0)
        }
    }

    @Suite("維持のとき")
    struct Maintaining {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .inProgress(try Goal.maintaining()), today: GoalLinkCapsuleTests.today,
                    weightTrend: nil))
        }

        @Test("保つ体重と一周の輪にすること")
        func showsTargetAndFullCircle() {
            #expect(entry.text == "65.0 kg を保つ")
            #expect(entry.progressPercent == 100)
        }
    }

    @Suite("期限より前に達成したとき")
    struct Achieved {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .achievedBeforeDeadline(try Goal.losing()),
                    today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(GoalLinkCapsuleTests.today, kilograms: [69.0])))
        }

        @Test("「達成しました」と一周の輪にすること")
        func showsAchievedAndFullCircle() {
            #expect(entry.text == "達成しました")
            #expect(entry.progressPercent == 100)
        }
    }

    @Suite("期限が来たとき")
    struct DeadlineReached {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .deadlineReached(try Goal.losing()), today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(GoalLinkCapsuleTests.today, kilograms: [68.4])))
        }

        @Test("今日の体重の傾向からの残りと進み具合にすること")
        func showsRemainingAndProgress() {
            #expect(entry.text == "あと 0.4 kg")
            #expect(entry.progressPercent == 91)
        }
    }

    @Suite("期限後の維持のとき")
    struct MaintainingAfterDeadline {
        let entry: GoalLinkCapsule

        init() throws {
            entry = try #require(
                GoalLinkCapsule(
                    status: .maintainingAfterDeadline(
                        try Goal.maintaining(), previous: try Goal.losing()),
                    today: GoalLinkCapsuleTests.today,
                    weightTrend: .starting(GoalLinkCapsuleTests.today, kilograms: [65.2])))
        }

        @Test("維持の目標の保つ体重と一周の輪にすること")
        func showsTargetAndFullCircle() {
            #expect(entry.text == "65.0 kg を保つ")
            #expect(entry.progressPercent == 100)
        }
    }

    @Suite("目標がないあいだ")
    struct NoGoal {
        let entry: GoalLinkCapsule?

        init() {
            entry = GoalLinkCapsule(
                status: .noGoal, today: GoalLinkCapsuleTests.today, weightTrend: nil)
        }

        @Test("入口を置かないこと")
        func hasNoEntry() {
            #expect(entry == nil)
        }
    }
}
