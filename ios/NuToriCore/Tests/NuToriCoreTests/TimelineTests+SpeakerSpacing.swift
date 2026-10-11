import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("項目の前を詰めるか空けるか")
    struct SpeakerSpacing {
        let morning: WeightRecord
        let breakfast: MealCard
        let question: SentText
        let reply: AiUtterance
        let thanks: SentText
        let lunchText: SentText
        let lunch: MealCard
        let lunchSide: MealCard
        let snackQuestion: SentText
        let snackReply: AiUtterance
        let snack: MealCard
        let evening: WeightRecord
        let notice: Notice
        let night: WeightRecord
        let afterWeight: SentText
        let timeline: Timeline

        init() throws {
            morning = try .manual(72.9, at: "2026-09-24T07:00:00+09:00", in: "Asia/Tokyo")
            breakfast = try .fixture(eatenAt: "2026-09-24T07:40:00+09:00", status: .estimated)
            question = try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T08:00:00+09:00")
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
            snackQuestion = try .fixture("おやつは何がいい？", sentAt: "2026-09-24T15:00:00+09:00")
            snackReply = AiUtterance(
                id: UUID(), body: "ナッツはどうでしょう。", sentTextId: snackQuestion.id, mealIds: [])
            snack = try .fixture(eatenAt: "2026-09-24T15:30:00+09:00", status: .estimated)
            evening = try .manual(72.8, at: "2026-09-24T20:00:00+09:00", in: "Asia/Tokyo")
            notice = try .missedWeightRecord(issuedAt: "2026-09-24T21:00:00+09:00")
            night = try .manual(72.6, at: "2026-09-24T22:00:00+09:00", in: "Asia/Tokyo")
            afterWeight = try .fixture("体重が減った", sentAt: "2026-09-24T22:10:00+09:00")
            let replied = SentTextStatus(classification: .conversation, reply: .replied)
            timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [morning, evening, night], rejectedLines: [],
                    meals: [breakfast, lunch, lunchSide, snack], notices: [notice],
                    undelivered: .none,
                    conversation: Timeline.Conversation(
                        sentTexts: [
                            question, thanks, lunchText, snackQuestion, afterWeight,
                        ],
                        statuses: [
                            question.id: replied, thanks.id: replied,
                            lunchText.id: SentTextStatus(
                                classification: .meal, reply: .notRequested),
                            snackQuestion.id: replied, afterWeight.id: replied,
                        ],
                        replies: [reply, snackReply], streams: [:])),
                firstDay: CalendarDay(year: 2026, month: 9, day: 24),
                today: CalendarDay(year: 2026, month: 9, day: 24))
        }

        /// 項目の ID と、その前を詰めるか空けるか
        private var spacings: [String: Timeline.ItemSpacing] {
            let day = timeline.days[0]
            return Dictionary(
                uniqueKeysWithValues: day.items.map { ($0.id, day.spacing(before: $0)) })
        }

        @Test("自分の吹き出しと返事のあいだを、どちらの向きでも空けること")
        func betweenSelfAndAi() {
            #expect(spacings[itemId(replying: reply)] == .apart)
            #expect(spacings[itemId(of: thanks)] == .apart)
        }

        @Test("記録のすぐ下の自分の吹き出しを詰めること")
        func bubblesAfterRecords() {
            #expect(spacings[itemId(of: question)] == .close)
            #expect(spacings[itemId(of: afterWeight)] == .close)
        }

        @Test("自分の吹き出しが続くと詰めること")
        func consecutiveBubbles() {
            #expect(spacings[itemId(of: lunchText)] == .close)
        }

        @Test("文章の食事のカードを、その文章の吹き出しと、同じ文章の食事のすぐ下に詰めること")
        func writtenMealsBelowBubble() {
            #expect(spacings[Timeline.Item.meal(lunch).id] == .close)
            #expect(spacings[Timeline.Item.meal(lunchSide).id] == .close)
        }

        @Test("返事のすぐ下の写真の食事を空けること")
        func photoMealAfterReply() {
            #expect(spacings[Timeline.Item.meal(snack).id] == .apart)
        }

        @Test("記録のあとの記録を詰めること")
        func recordsAfterRecords() {
            #expect(spacings[Timeline.Item.meal(breakfast).id] == .close)
            #expect(spacings[Timeline.Item.weightRecord(evening).id] == .close)
        }

        @Test("知らせの前後を空けること")
        func aroundNotice() {
            #expect(spacings[itemId(of: notice)] == .apart)
            #expect(spacings[Timeline.Item.weightRecord(night).id] == .apart)
        }

        @Test("日の最初の項目を詰めること")
        func firstItemOfDay() {
            #expect(spacings[Timeline.Item.weightRecord(morning).id] == .close)
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

        /// 答えていない、今日の知らせの項目の ID
        private func itemId(of notice: Notice) -> String {
            Timeline.Item.notice(NoticeCard(notice: notice, form: .awaitingAnswer)).id
        }
    }

    @Suite("返事が日の最初の項目のとき")
    struct ReplyFirstInDay {
        let reply: Timeline.Item
        let day: Timeline.Day

        init() throws {
            let morning = try SentText.fixture("おはよう", sentAt: "2026-09-25T07:00:00+09:00")
            reply = .reply(
                TimelineReply(
                    id: UUID(), sentTextId: UUID(), body: "おはようございます。", isGrowing: false,
                    referencedMeals: []))
            day = Timeline.Day(
                day: CalendarDay(year: 2026, month: 9, day: 25),
                items: [
                    reply,
                    .sentText(SentTextBubble(sentText: morning, replyLine: nil, rejectedLine: nil)),
                ],
                food: .noMeals)
        }

        @Test("詰めること")
        func closesFirstReply() {
            #expect(day.spacing(before: reply) == .close)
        }
    }
}
