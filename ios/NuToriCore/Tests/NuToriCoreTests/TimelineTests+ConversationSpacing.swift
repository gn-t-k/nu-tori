import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("項目の前を詰めるか空けるか")
    struct ConversationSpacing {
        let question: SentText
        let reply: AiUtterance
        let thanks: SentText
        let lunchText: SentText
        let lunch: MealCard
        let lunchSide: MealCard
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
            lunchText = try .fixture("昼はうどんとおにぎり", sentAt: "2026-09-24T12:40:00+09:00")
            lunch = try PlacingConversation.writtenMeal(
                from: lunchText, eatenAt: "2026-09-24T12:40:00+09:00",
                sentAt: "2026-09-24T12:40:00+09:00")
            lunchSide = try PlacingConversation.writtenMeal(
                from: lunchText, eatenAt: "2026-09-24T12:40:00+09:00",
                sentAt: "2026-09-24T12:40:00+09:00")
            evening = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
            afterWeight = try .fixture("体重が増えた", sentAt: "2026-09-24T21:10:00+09:00")
            night = try .manual(72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
            nextDay = try .fixture("おはよう", sentAt: "2026-09-25T07:00:00+09:00")
            let replied = SentTextStatus(classification: .conversation, reply: .replied)
            timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [evening, night], rejectedLines: [], meals: [lunch, lunchSide],
                    notices: [], undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: [question, thanks, lunchText, afterWeight, nextDay],
                        statuses: [
                            question.id: replied, thanks.id: replied,
                            lunchText.id: SentTextStatus(
                                classification: .meal, reply: .notRequested),
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

        @Test("文章の食事のカードを、その文章の吹き出しと、同じ文章の食事のすぐ下に詰めること")
        func writtenMealsBelowBubble() {
            #expect(spacings[0][Timeline.Item.meal(lunch).id] == .close)
            #expect(spacings[0][Timeline.Item.meal(lunchSide).id] == .close)
        }

        @Test("発言のすぐあとの記録を空け、記録のあとの記録を詰めること")
        func recordsAfterUtterances() {
            #expect(spacings[0][Timeline.Item.weightRecord(night).id] == .apart)
            #expect(spacings[0][Timeline.Item.weightRecord(evening).id] == .close)
        }

        /// 送った文章の吹き出しの項目の ID
        private func itemId(of sentText: SentText) -> String {
            Timeline.Item.sentText(
                SentTextBubble(sentText: sentText, replyLine: nil, rejectedLine: nil)
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
