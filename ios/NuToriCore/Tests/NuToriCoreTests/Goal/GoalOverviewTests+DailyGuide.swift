import Foundation
import NuToriCore
import Testing

extension GoalOverviewTests {
    @Suite("今の1日の目安")
    struct CurrentDailyGuide {
        @Test("今日に当たっている1日の目安と、当て始めた日を出すこと")
        func showsSince() throws {
            let goal = try Goal.losing()
            let (estimates, guides) = EnergyChart.records(
                goal,
                [
                    (GoalOverviewTests.day(10, 1), 2190, 1880),
                    (GoalOverviewTests.day(10, 12), 2160, 1860),
                ])
            let overview = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(10, 20), goals: [goal], dailyGuides: guides,
                    expenditureEstimates: estimates))

            #expect(overview.currentDailyGuide?.energyKilocalories == 1860)
            #expect(overview.currentDailyGuideSince == "10月12日から")
        }

        @Test("1日の目安がまだ届いていなければ、当て始めた日も出さないこと")
        func hidesSinceWithoutGuide() throws {
            let overview = try #require(
                GoalOverviewTests.overview(
                    today: GoalOverviewTests.day(10, 20), goals: [try .losing()]))

            #expect(overview.currentDailyGuideSince == nil)
        }
    }
}
