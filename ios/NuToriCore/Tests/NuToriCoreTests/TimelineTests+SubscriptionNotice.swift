import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("サブスクリプションの知らせ")
    struct PlacingSubscriptionNotice {
        static let firstDay = CalendarDay(year: 2026, month: 10, day: 21)
        static let lastDay = CalendarDay(year: 2026, month: 11, day: 19)
        static let threeDaysLeftDay = CalendarDay(year: 2026, month: 11, day: 17)

        let record: WeightRecord
        let timeline: Timeline

        /// 最後の日の朝に体重を記録し、無料体験のあと3日と今日までの知らせがある
        init() throws {
            record = try .manual(67.9, at: "2026-11-19T07:00:00+09:00", in: "Asia/Tokyo")
            timeline = Timeline(
                input: Timeline.Input(
                    goalRecords: .fixture(goals: [], weightRecords: [record]),
                    rejectedLines: [], meals: [], notices: [], undelivered: .none,
                    conversation: .none,
                    subscriptionNotices: [
                        SubscriptionNotice(
                            kind: .freeTrialEndsSoon(lastDay: Self.lastDay),
                            day: Self.threeDaysLeftDay),
                        SubscriptionNotice(kind: .freeTrialLastDay, day: Self.lastDay),
                    ]),
                firstDay: Self.firstDay, today: Self.lastDay)
        }

        @Test("その日の記録より上の、タイムラインの先頭に置くこと")
        func placesAtTopOfDay() {
            #expect(
                GoalNoticeScene.itemIds(on: Self.lastDay, in: timeline) == [
                    "subscription-free-trial-last-day", "record-\(record.id.uuidString)",
                ])
            #expect(
                GoalNoticeScene.itemIds(on: Self.threeDaysLeftDay, in: timeline) == [
                    "subscription-free-trial-ends-soon"
                ])
        }

        @Test("アプリの話す項目として置くこと")
        func speaksAsApp() throws {
            let item = try #require(
                timeline.days.first { $0.day == Self.lastDay }?.items.first)

            #expect(item.speaker == .app)
        }

        @Test("帯の下の答えていない知らせの1行に数えないこと")
        func isNotInUnansweredLines() {
            #expect(timeline.unansweredNoticeLines.isEmpty)
        }
    }
}
