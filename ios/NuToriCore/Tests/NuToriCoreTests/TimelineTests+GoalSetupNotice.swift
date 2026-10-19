import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    /// 東京の 2026-09-24 に見る。目標を立てる知らせは 2026-09-22 の 7:00 に出た
    @Suite("目標を立てる知らせ")
    struct PlacingGoalSetupNotice {
        static let today = CalendarDay(year: 2026, month: 9, day: 24)
        static let issuedDay = CalendarDay(year: 2026, month: 9, day: 22)

        static func timeline(notices: [Notice], meals: [MealCard] = []) -> Timeline {
            Timeline(
                input: Timeline.Input(
                    goalRecords: GoalRecords(
                        goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                        weightTrend: nil, weightRecords: []), rejectedLines: [], meals: meals,
                    notices: notices, undelivered: .none, conversation: .none),
                firstDay: CalendarDay(year: 2026, month: 9, day: 20), today: today)
        }

        static func items(on day: CalendarDay, in timeline: Timeline) -> [Timeline.Item] {
            timeline.days.first { $0.day == day }?.items ?? []
        }

        @Suite("答えていないとき")
        struct Unanswered {
            let notice: Notice
            let meal: MealCard
            let timeline: Timeline

            init() throws {
                notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-22T07:00:00+09:00")
                meal = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-22T06:40:00+09:00", sentAt: "2026-09-22T06:40:00+09:00"),
                    status: .estimated, recordedOnThisDevice: true)
                timeline = PlacingGoalSetupNotice.timeline(notices: [notice], meals: [meal])
            }

            @Test("出したときのタイムゾーンの日に、出した時刻の順で置くこと")
            func placesAtIssuedTime() {
                #expect(
                    PlacingGoalSetupNotice.items(on: PlacingGoalSetupNotice.issuedDay, in: timeline)
                        == [.meal(meal), .goalSetupNotice(notice)])
            }

            @Test("アプリからの知らせとして、自分の記録と間を空けること")
            func isSpokenByApp() {
                #expect(Timeline.Item.goalSetupNotice(notice).speaker == .app)
            }

            @Test("カードの知らせとして引けること")
            func isFound() {
                #expect(timeline.goalSetupNotice == notice)
            }
        }

        @Suite("目標が決まって答えたとき")
        struct Answered {
            let notice: Notice
            let timeline: Timeline

            init() throws {
                notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-22T07:00:00+09:00"
                ).responded(
                    Notice.Response(
                        respondedAt: try Date("2026-09-22T07:05:00+09:00", strategy: .iso8601),
                        timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
                timeline = PlacingGoalSetupNotice.timeline(notices: [notice])
            }

            @Test("カードを残すこと")
            func keepsCard() {
                #expect(
                    PlacingGoalSetupNotice.items(on: PlacingGoalSetupNotice.issuedDay, in: timeline)
                        == [.goalSetupNotice(notice)])
            }

            @Test("帯の下の1行に出さないこと")
            func hasNoUnansweredLine() {
                #expect(timeline.unansweredNoticeLines.isEmpty)
            }
        }

        @Suite("使い始めた日より前に出していたとき")
        struct BeforeFirstDay {
            @Test("使い始めた日に置くこと")
            func placesOnFirstDay() throws {
                let notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-18T07:00:00+09:00")
                let timeline = PlacingGoalSetupNotice.timeline(notices: [notice])

                #expect(
                    PlacingGoalSetupNotice.items(
                        on: CalendarDay(year: 2026, month: 9, day: 20), in: timeline)
                        == [.goalSetupNotice(notice)])
            }
        }

        @Suite("知らせが無いとき")
        struct Missing {
            @Test("カードの知らせが無いこと")
            func hasNone() throws {
                let timeline = PlacingGoalSetupNotice.timeline(notices: [
                    try .missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")
                ])

                #expect(timeline.goalSetupNotice == nil)
            }
        }
    }
}
