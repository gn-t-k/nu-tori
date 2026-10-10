import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("隣り合う発言の見分け")
    struct ConversationSpacing {
        let question: SentText
        let reply: AiUtterance
        let thanks: SentText
        let afterWeight: SentText
        let nextDay: SentText
        let timeline: Timeline

        init() throws {
            question = try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T12:11:00+09:00")
            reply = AiUtterance(
                id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: question.id, mealIds: [])
            thanks = try .fixture("ありがとう", sentAt: "2026-09-24T12:30:00+09:00")
            afterWeight = try .fixture("体重が増えた", sentAt: "2026-09-24T21:10:00+09:00")
            nextDay = try .fixture("おはよう", sentAt: "2026-09-25T07:00:00+09:00")
            let replied = SentTextStatus(classification: .conversation, reply: .replied)
            timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [
                        try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                    ],
                    rejectedLines: [], meals: [], notices: [],
                    conversation: Timeline.Conversation(
                        sentTexts: [question, thanks, afterWeight, nextDay],
                        statuses: [
                            question.id: replied, thanks.id: replied, afterWeight.id: replied,
                            nextDay.id: replied,
                        ],
                        replies: [reply])),
                firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                today: CalendarDay(year: 2026, month: 9, day: 25))
        }

        /// 日ごとに、発言の ID と、すぐ前が発言か
        private var follows: [[String: Bool]] {
            timeline.days.map { day in
                Dictionary(
                    uniqueKeysWithValues: day.items.compactMap { item in
                        switch item {
                        case .sentText, .reply: (item.id, day.followsUtterance(item))
                        default: nil
                        }
                    })
            }
        }

        @Test("送った文章と返事、返事と次の送った文章を、隣り合う発言とすること")
        func adjacentUtterances() {
            #expect(follows[0]["reply-\(reply.id.uuidString)"] == true)
            #expect(follows[0]["sent-text-\(thanks.id.uuidString)"] == true)
        }

        @Test("あいだに記録がある発言と、日の最初の発言を、隣り合わないとすること")
        func separatedUtterances() {
            #expect(follows[0]["sent-text-\(question.id.uuidString)"] == false)
            #expect(follows[0]["sent-text-\(afterWeight.id.uuidString)"] == false)
            #expect(follows[1]["sent-text-\(nextDay.id.uuidString)"] == false)
        }
    }
}
