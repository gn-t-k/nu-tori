import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("項目の前を詰めるか空けるか")
    struct ConversationSpacing {
        let question: SentText
        let reply: AiUtterance
        let thanks: SentText
        let afternoon: WeightRecord
        let evening: WeightRecord
        let afterWeight: SentText
        let night: WeightRecord
        let nextDay: SentText
        let timeline: Timeline

        init() throws {
            question = try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T12:11:00+09:00")
            reply = AiUtterance(
                id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: question.id, mealIds: [])
            thanks = try .fixture("ありがとう", sentAt: "2026-09-24T12:30:00+09:00")
            afternoon = try .manual(72.5, at: "2026-09-24T15:00:00+09:00", in: "Asia/Tokyo")
            evening = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
            afterWeight = try .fixture("体重が増えた", sentAt: "2026-09-24T21:10:00+09:00")
            night = try .manual(72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
            nextDay = try .fixture("おはよう", sentAt: "2026-09-25T07:00:00+09:00")
            let replied = SentTextStatus(classification: .conversation, reply: .replied)
            timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [afternoon, evening, night], rejectedLines: [], meals: [],
                    notices: [], undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: [question, thanks, afterWeight, nextDay],
                        statuses: [
                            question.id: replied, thanks.id: replied,
                            afterWeight.id: replied, nextDay.id: replied,
                        ],
                        replies: [reply], streams: [:])),
                firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                today: CalendarDay(year: 2026, month: 9, day: 25))
        }

        /// 日ごとに、項目の ID と、その前を詰めるか空けるか
        private var spacings: [[String: Timeline.ItemSpacing]] {
            timeline.days.map { day in
                Dictionary(
                    uniqueKeysWithValues: day.items.map { ($0.id, day.spacing(before: $0)) })
            }
        }

        @Test("送った文章と返事、返事と次の送った文章を、隣り合う発言として詰めること")
        func adjacentUtterances() {
            #expect(spacings[0][itemId(replying: reply)] == .close)
            #expect(spacings[0][itemId(of: thanks)] == .close)
        }

        @Test("あいだに記録がある発言と、日の最初の発言を空けること")
        func separatedUtterances() {
            #expect(spacings[0][itemId(of: question)] == .apart)
            #expect(spacings[0][itemId(of: afterWeight)] == .apart)
            #expect(spacings[1][itemId(of: nextDay)] == .apart)
        }

        @Test("発言のすぐあとの記録を空け、記録のあとの記録を詰めること")
        func recordsAfterUtterances() {
            #expect(spacings[0][Timeline.Item.weightRecord(night).id] == .apart)
            #expect(spacings[0][Timeline.Item.weightRecord(evening).id] == .close)
        }

        /// 送った文章の吹き出しの項目の ID
        private func itemId(of sentText: SentText) -> String {
            Timeline.Item.sentText(
                SentTextBubble(sentText: sentText, meals: [], replyLine: nil, rejectedLine: nil)
            )
            .id
        }

        /// 返事の項目の ID
        private func itemId(replying reply: AiUtterance) -> String {
            Timeline.Item.reply(
                TimelineReply(
                    id: reply.id, sentTextId: reply.sentTextId, body: reply.body, isGrowing: false,
                    referencedMeals: [])
            ).id
        }
    }
}
