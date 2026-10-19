import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("週の振り返り")
    struct WeeklyReview {
        @Test("開いたところと、何週前の週かを載せること")
        func opened() {
            let events: [ClientUsageEvent] = [
                .weeklyReviewOpened(entry: .weeklyReviewCard, weeksAgo: 1),
                .weeklyReviewOpened(entry: .goalScreen, weeksAgo: 0),
                .weeklyReviewOpened(entry: .daySummary, weeksAgo: 3),
            ]

            #expect(events.map(\.name) == Array(repeating: "weekly_review_opened", count: 3))
            #expect(
                events.map(\.fields) == [
                    ["entry": .token("weekly_review_card"), "weeks_ago": .count(1)],
                    ["entry": .token("goal_screen"), "weeks_ago": .count(0)],
                    ["entry": .token("day_summary"), "weeks_ago": .count(3)],
                ])
            #expect(events.allSatisfy { $0.screenToken == nil })
        }
    }
}
