import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    /// 使い始めた日（9月23日）に体重記録があり、24日は何も無く、今日（25日）も何も無いタイムライン
    @Suite("日の見出し")
    struct DayHeading {
        static func day(_ day: Int) throws -> Timeline.Day {
            let timeline = Timeline(
                input: Timeline.Input(
                    goalRecords: .fixture(weightRecords: [
                        try .manual(72.4, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                    ]), rejectedLines: [], meals: [], notices: [], undelivered: .none,
                    conversation: .none, subscriptionNotices: []),
                firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                today: CalendarDay(year: 2026, month: 9, day: 25)
            )
            return try #require(
                timeline.days.first { $0.day == CalendarDay(year: 2026, month: 9, day: day) })
        }

        @Suite("今日でなく項目も無い日")
        struct EmptyPastDay {
            let day: Timeline.Day

            init() throws {
                day = try DayHeading.day(24)
            }

            @Test("見出しを描かないこと")
            func hidesHeading() {
                #expect(!day.showsHeading)
            }
        }

        @Suite("項目の無い今日")
        struct EmptyToday {
            let day: Timeline.Day

            init() throws {
                day = try DayHeading.day(25)
            }

            @Test("見出しを描くこと")
            func showsHeading() {
                #expect(day.showsHeading)
            }
        }

        @Suite("項目のある日")
        struct DayWithItems {
            let day: Timeline.Day

            init() throws {
                day = try DayHeading.day(23)
            }

            @Test("見出しを描くこと")
            func showsHeading() {
                #expect(day.showsHeading)
            }
        }
    }
}
