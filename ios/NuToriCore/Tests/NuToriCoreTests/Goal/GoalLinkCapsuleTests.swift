import Foundation
import NuToriCore
import Testing

@Suite("左上の目標の入口")
struct GoalLinkCapsuleTests {
    let today = CalendarDay(year: 2026, month: 11, day: 2)

    @Test("進行中の減量は、今日の体重の傾向から残りの kg と進み具合を出すこと")
    func losingInProgress() throws {
        let goal = try Goal.losing()

        let entry = try #require(
            GoalLinkCapsule(
                status: .inProgress(goal), today: today,
                weightTrend: .starting(today.advanced(by: -1), kilograms: [70.6, 70.2])))

        #expect(entry.text == "あと 2.2 kg")
        #expect(entry.progressPercent == 50)
    }

    @Test("進行中の増量も、開始の体重から目標体重へ進んだ分を進み具合にすること")
    func gainingInProgress() throws {
        let losing = try Goal.losing()
        let goal = Goal(
            id: UUID(), startedDay: losing.startedDay, startingWeightTrendKilograms: 60.0,
            targetWeightKilograms: 64.0, decidedAt: losing.decidedAt, timeZone: losing.timeZone,
            direction: .gain(
                Goal.WeightChange(
                    deadlineDay: CalendarDay(year: 2026, month: 12, day: 24),
                    pacePlan: .standard)),
            achievement: nil, deadlineConfirmation: nil, closure: nil)

        let entry = try #require(
            GoalLinkCapsule(
                status: .inProgress(goal), today: today,
                weightTrend: .starting(today, kilograms: [61.0])))

        #expect(entry.text == "あと 3.0 kg")
        #expect(entry.progressPercent == 25)
    }

    @Test("目標体重を越えたら、残りを 0 kg、輪を一周で止めること")
    func overshot() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .inProgress(try Goal.losing()), today: today,
                weightTrend: .starting(today, kilograms: [67.5])))

        #expect(entry.text == "あと 0.0 kg")
        #expect(entry.progressPercent == 100)
    }

    @Test("今日以前の体重の傾向がまだ届いていなければ、開始の体重から数えること")
    func noWeightTrend() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .inProgress(try Goal.losing()), today: today,
                weightTrend: .starting(today.advanced(by: 1), kilograms: [70.0])))

        #expect(entry.text == "あと 4.4 kg")
        #expect(entry.progressPercent == 0)
    }

    @Test("維持は、保つ体重と一周の輪にすること")
    func maintaining() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .inProgress(try Goal.maintaining()), today: today, weightTrend: nil))

        #expect(entry.text == "65.0 kg を保つ")
        #expect(entry.progressPercent == 100)
    }

    @Test("期限より前に達成したら、「達成しました」と一周の輪にすること")
    func achieved() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .achievedBeforeDeadline(try Goal.losing()), today: today,
                weightTrend: .starting(today, kilograms: [69.0])))

        #expect(entry.text == "達成しました")
        #expect(entry.progressPercent == 100)
    }

    @Test("期限が来たら、今日の体重の傾向からの残りと進み具合にすること")
    func deadlineReached() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .deadlineReached(try Goal.losing()), today: today,
                weightTrend: .starting(today, kilograms: [68.4])))

        #expect(entry.text == "あと 0.4 kg")
        #expect(entry.progressPercent == 91)
    }

    @Test("期限後の維持は、維持の目標の保つ体重と一周の輪にすること")
    func maintainingAfterDeadline() throws {
        let entry = try #require(
            GoalLinkCapsule(
                status: .maintainingAfterDeadline(
                    try Goal.maintaining(), previous: try Goal.losing()),
                today: today, weightTrend: .starting(today, kilograms: [65.2])))

        #expect(entry.text == "65.0 kg を保つ")
        #expect(entry.progressPercent == 100)
    }

    @Test("目標がないあいだは、入口を置かないこと")
    func noGoal() {
        #expect(GoalLinkCapsule(status: .noGoal, today: today, weightTrend: nil) == nil)
    }
}
