import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    /// 2026-10-01 に始めた、12月24日（木）までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）の知らせ
    @Suite("目標の知らせ")
    struct PlacingGoalNotice {
        @Suite("期限より前に達成したとき")
        struct Achieved {
            let goal: Goal
            let record: WeightRecord
            let timeline: Timeline

            init() throws {
                goal = try GoalNoticeScene.losing(
                    achievedAt: "2026-11-08T07:30:00+09:00",
                    achievedDay: CalendarDay(year: 2026, month: 11, day: 8))
                record = try .manual(67.9, at: "2026-11-08T07:00:00+09:00", in: "Asia/Tokyo")
                timeline = GoalNoticeScene.timeline(
                    goals: [goal], weightRecords: [record],
                    today: CalendarDay(year: 2026, month: 11, day: 9))
            }

            @Test("判定した時刻の位置に置くこと")
            func placesAtJudgedTime() {
                #expect(
                    GoalNoticeScene.itemIds(
                        on: CalendarDay(year: 2026, month: 11, day: 8), in: timeline) == [
                            "record-\(record.id.uuidString)",
                            "goal-achieved-\(goal.id.uuidString)",
                        ])
            }

            @Test("期限より何日早く届いたかを言い、次の目標を選べること")
            func saysDaysEarly() throws {
                let notice = try #require(GoalNoticeScene.notices(in: timeline).first)
                #expect(notice.headline == "目標を達成しました")
                #expect(
                    notice.body
                        == "期限の12月24日より 46 日早く、体重の傾向が 68.0 kg に届きました。")
                #expect(notice.actionTitle == "次の目標を選ぶ")
                #expect(notice.setupEntry == .chooseNextGoal)
                #expect(notice.unavailableText == nil)
            }

            @Test("帯の下の1行に出さないこと")
            func isNotInUnansweredLines() {
                #expect(timeline.unansweredNoticeLines.isEmpty)
            }
        }

        @Suite("期限の日を確定したとき")
        struct DeadlineReached {
            let goal: Goal
            let timeline: Timeline

            init() throws {
                goal = try GoalNoticeScene.losing(
                    confirmedAt: "2026-12-25T06:10:00+09:00", deadlineWeightTrendKilograms: 68.8)
                timeline = GoalNoticeScene.timeline(
                    goals: [goal], weightRecords: [],
                    today: CalendarDay(year: 2026, month: 12, day: 25))
            }

            @Test("確定した時刻の位置に置くこと")
            func placesAtConfirmedTime() {
                #expect(
                    GoalNoticeScene.itemIds(
                        on: CalendarDay(year: 2026, month: 12, day: 25), in: timeline) == [
                            "goal-deadline-\(goal.id.uuidString)"
                        ])
            }

            @Test("開始からの変化と残りと、期限後の維持に移る月曜を言うこと")
            func saysResult() throws {
                let notice = try #require(GoalNoticeScene.notices(in: timeline).first)
                #expect(notice.headline == "期限の12月24日を迎えました")
                #expect(
                    notice.body
                        == "開始から −3.6 kg・目標まであと 0.8 kg でした。選ばなければ、12月28日（月）から今の体重を保つ目標で続けます。"
                )
                #expect(notice.actionTitle == "次の目標を選ぶ")
                #expect(notice.setupEntry == .chooseNextGoal)
            }
        }

        @Suite("期限の日の体重の傾向が目標体重を越えて確定したとき")
        struct DeadlineReachedBeyondTarget {
            let notice: GoalNotice?

            init() throws {
                let goal = try GoalNoticeScene.losing(
                    confirmedAt: "2026-12-25T06:10:00+09:00", deadlineWeightTrendKilograms: 67.6)
                notice =
                    GoalNoticeScene.notices(
                        in: GoalNoticeScene.timeline(
                            goals: [goal], weightRecords: [],
                            today: CalendarDay(year: 2026, month: 12, day: 25))
                    ).first
            }

            @Test("目標まであと 0.0 kg だったと言うこと")
            func saysNoneRemaining() {
                #expect(
                    notice?.body
                        == "開始から −4.8 kg・目標まであと 0.0 kg でした。選ばなければ、12月28日（月）から今の体重を保つ目標で続けます。"
                )
            }
        }

        @Suite("達成と期限の日の確定の両方があるとき")
        struct BothAchievedAndConfirmed {
            let goal: Goal
            let timeline: Timeline

            init() throws {
                goal = try Goal.losing(
                    achievement: .inTokyo(
                        on: CalendarDay(year: 2026, month: 12, day: 26),
                        judgedAt: "2026-12-26T07:30:00+09:00"),
                    deadlineConfirmation: .inTokyo(
                        weightTrendKilograms: 68.4, confirmedAt: "2026-12-25T06:10:00+09:00"))
                timeline = GoalNoticeScene.timeline(
                    goals: [goal], weightRecords: [],
                    today: CalendarDay(year: 2026, month: 12, day: 26))
            }

            @Test("早いほう1つだけを出すこと")
            func placesEarlierOnly() {
                #expect(
                    timeline.days.flatMap(\.items).map(\.id) == [
                        "goal-deadline-\(goal.id.uuidString)"
                    ])
            }
        }

        @Suite("期限のあと次の目標を選ばずに期限後の維持に移ったとき")
        struct MovedToMaintenance {
            let previous: Goal
            let maintenance: Goal
            let timeline: Timeline

            init() throws {
                let monday = CalendarDay(year: 2026, month: 12, day: 28)
                maintenance = try Goal.maintaining(
                    startedOn: monday, kilograms: 68.8, decidedAt: "2026-12-28T06:10:00+09:00")
                previous = try GoalNoticeScene.losing(
                    confirmedAt: "2026-12-25T06:10:00+09:00", deadlineWeightTrendKilograms: 68.8,
                    closure: Goal.Closure(
                        endedDay: monday, nextGoalId: maintenance.id,
                        endReason: .movedToMaintenance))
                timeline = GoalNoticeScene.timeline(
                    goals: [previous, maintenance], weightRecords: [], today: monday)
            }

            @Test("期限の知らせと、維持の目標を決めた時刻の位置に期限後の維持の知らせを置くこと")
            func placesBothNotices() {
                #expect(
                    timeline.days.flatMap(\.items).map(\.id) == [
                        "goal-deadline-\(previous.id.uuidString)",
                        "goal-maintenance-\(maintenance.id.uuidString)",
                    ])
            }

            @Test("期限後の維持の知らせは、保つ体重を言い、次の目標を立てられること")
            func maintenanceNoticeSaysTarget() throws {
                let notice = try #require(GoalNoticeScene.notices(in: timeline).last)
                #expect(notice.headline == "今の体重を保つ目標に切り替えました")
                #expect(
                    notice.body
                        == "12月24日の期限のあと次の目標を選ばなかったので、68.8 kg を保つ目標で続けています。")
                #expect(notice.actionTitle == "次の目標を立てる")
                #expect(notice.setupEntry == .setNextGoal)
                #expect(notice.unavailableText == nil)
            }

            @Test("期限の知らせのボタンは押せず、期限後の維持に切り替わった理由を添えること")
            func deadlineNoticeIsUnavailable() throws {
                let notice = try #require(GoalNoticeScene.notices(in: timeline).first)
                #expect(notice.unavailability == .movedToMaintenance)
                #expect(notice.unavailableText == "今の体重を保つ目標に切り替わったので、ここからは選べません。")
            }
        }

        @Suite("達成のあと次の目標を決めたとき")
        struct SwitchedAfterAchievement {
            let timeline: Timeline

            init() throws {
                let next = try Goal.maintaining()
                let achieved = try GoalNoticeScene.losing(
                    achievedAt: "2026-11-08T07:30:00+09:00",
                    achievedDay: CalendarDay(year: 2026, month: 11, day: 8),
                    closure: Goal.Closure(
                        endedDay: CalendarDay(year: 2026, month: 11, day: 10),
                        nextGoalId: next.id, endReason: .switched))
                let nextStarted = try Goal.maintaining(
                    id: next.id, startedOn: CalendarDay(year: 2026, month: 11, day: 10),
                    kilograms: 67.9, decidedAt: "2026-11-10T21:00:00+09:00")
                timeline = GoalNoticeScene.timeline(
                    goals: [achieved, nextStarted], weightRecords: [],
                    today: CalendarDay(year: 2026, month: 11, day: 10))
            }

            @Test("達成の知らせのボタンは押せず、次の目標を決めた理由を添えること")
            func achievedNoticeIsUnavailable() throws {
                let notice = try #require(GoalNoticeScene.notices(in: timeline).first)
                #expect(notice.unavailability == .switched)
                #expect(notice.unavailableText == "次の目標を決めたので、ここからは選べません。")
            }
        }
    }
}
