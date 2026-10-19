import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("目標の画面")
    struct GoalScreen {
        @Test("開いたところと、目標の状態を載せること")
        func opened() {
            let events: [ClientUsageEvent] = [
                .goalScreenOpened(entry: .goalLink, status: .inProgress),
                .goalScreenOpened(entry: .dailyGuideChangeNotice, status: .achievedBeforeDeadline),
                .goalScreenOpened(entry: .daySummary, status: .deadlineReached),
                .goalScreenOpened(entry: .weightScreen, status: .maintainingAfterDeadline),
            ]

            #expect(events.map(\.name) == Array(repeating: "goal_screen_opened", count: 4))
            #expect(
                events.map(\.fields) == [
                    ["entry": .token("goal_link"), "goal_status": .token("in_progress")],
                    [
                        "entry": .token("daily_guide_change_notice"),
                        "goal_status": .token("achieved_before_deadline"),
                    ],
                    ["entry": .token("day_summary"), "goal_status": .token("deadline_reached")],
                    [
                        "entry": .token("weight_screen"),
                        "goal_status": .token("maintaining_after_deadline"),
                    ],
                ])
            #expect(events.allSatisfy { $0.screenToken == nil })
        }

        @Test("目標の状態から送る状態を出し、目標がなければ出さないこと")
        func statusFromGoalStatus() throws {
            let goal = try Goal.losing()
            let maintaining = try Goal.maintaining()

            #expect(ClientUsageEvent.GoalScreenStatus(.noGoal) == nil)
            #expect(ClientUsageEvent.GoalScreenStatus(.inProgress(goal)) == .inProgress)
            #expect(
                ClientUsageEvent.GoalScreenStatus(.achievedBeforeDeadline(goal))
                    == .achievedBeforeDeadline)
            #expect(ClientUsageEvent.GoalScreenStatus(.deadlineReached(goal)) == .deadlineReached)
            #expect(
                ClientUsageEvent.GoalScreenStatus(
                    .maintainingAfterDeadline(maintaining, previous: goal))
                    == .maintainingAfterDeadline)
        }
    }
}
