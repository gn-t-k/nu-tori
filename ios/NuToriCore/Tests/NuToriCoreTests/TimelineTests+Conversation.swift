import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("送った文章と返事の置き場")
    struct PlacingConversation {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        static func timeline(
            weightRecords: [WeightRecord] = [],
            meals: [MealCard] = [],
            conversation: Timeline.Conversation,
            firstDay: CalendarDay = day
        ) -> Timeline {
            Timeline(
                input: Timeline.Input(
                    weightRecords: weightRecords, rejectedLines: [], meals: meals, notices: [],
                    undelivered: .none, conversation: conversation),
                firstDay: firstDay, today: day)
        }

        static func writtenMeal(
            from sentText: SentText, eatenAt: String, sentAt: String
        ) throws -> MealCard {
            MealCard(
                meal: try .fixture(
                    eatenAt: eatenAt, sentAt: sentAt, entry: .written(sentTextId: sentText.id),
                    photoIds: []),
                status: .estimated, recordedOnThisDevice: false)
        }

        @Suite("食事と読み分けた文章")
        struct MealText {
            let sentText: SentText
            let meal: MealCard
            let morning: WeightRecord
            let evening: WeightRecord
            let timeline: Timeline

            init() throws {
                sentText = try .fixture("昼はうどん", sentAt: "2026-09-24T12:11:00+09:00")
                meal = try PlacingConversation.writtenMeal(
                    from: sentText, eatenAt: "2026-09-24T12:11:00+09:00",
                    sentAt: "2026-09-24T12:11:00+09:00")
                morning = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                evening = try .manual(72.8, at: "2026-09-24T21:00:00+09:00", in: "Asia/Tokyo")
                timeline = PlacingConversation.timeline(
                    weightRecords: [evening, morning], meals: [meal],
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText],
                        statuses: [
                            sentText.id: SentTextStatus(classification: .meal, reply: .notRequested)
                        ], replies: [], streams: [:]))
            }

            @Test("送った時刻の位置に吹き出しを置き、そのすぐ下に文章の食事のカードを置くこと")
            func placesMealCardBelowBubble() {
                #expect(
                    timeline.days.map(\.items) == [
                        [
                            .weightRecord(morning),
                            .sentText(
                                SentTextBubble(
                                    sentText: sentText, replyLine: nil, rejectedLine: nil)),
                            .meal(meal),
                            .weightRecord(evening),
                        ]
                    ])
            }
        }

        @Suite("文章の食事の時刻が送った時刻と違うとき")
        struct MealAtDifferentTime {
            let sentText: SentText
            let breakfast: MealCard
            let dinnerOfPreviousDay: MealCard
            let lunch: MealCard
            let morning: WeightRecord
            let timeline: Timeline

            init() throws {
                sentText = try .fixture(
                    "昨日の夜はカレー、朝はパン、昼はうどん", sentAt: "2026-09-24T12:11:00+09:00")
                dinnerOfPreviousDay = try PlacingConversation.writtenMeal(
                    from: sentText, eatenAt: "2026-09-23T19:00:00+09:00",
                    sentAt: "2026-09-24T12:11:00+09:00")
                breakfast = try PlacingConversation.writtenMeal(
                    from: sentText, eatenAt: "2026-09-24T08:00:00+09:00",
                    sentAt: "2026-09-24T12:11:00+09:00")
                lunch = try PlacingConversation.writtenMeal(
                    from: sentText, eatenAt: "2026-09-24T12:11:00+09:00",
                    sentAt: "2026-09-24T12:11:00+09:00")
                morning = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
                timeline = PlacingConversation.timeline(
                    weightRecords: [morning], meals: [lunch, breakfast, dinnerOfPreviousDay],
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText],
                        statuses: [
                            sentText.id: SentTextStatus(classification: .meal, reply: .notRequested)
                        ], replies: [], streams: [:]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23))
            }

            @Test("その時刻の位置（前の日を含む）にカードを置き、送った位置には吹き出しと同じ時刻の食事だけを残すこと")
            func placesMealAtItsTime() {
                #expect(
                    timeline.days.map(\.items) == [
                        [.meal(dinnerOfPreviousDay)],
                        [
                            .weightRecord(morning),
                            .meal(breakfast),
                            .sentText(
                                SentTextBubble(
                                    sentText: sentText, replyLine: nil, rejectedLine: nil)),
                            .meal(lunch),
                        ],
                    ])
            }

            @Test("その時刻の位置に置いたカードには、日を添えずに時刻を出すこと")
            func showsClockOnly() {
                #expect(dinnerOfPreviousDay.eatenTime == .clock(ClockTime(hour: 19, minute: 0)))
            }
        }

        @Suite("返事が届いたとき")
        struct Replied {
            let sentText: SentText
            let next: SentText
            let reply: AiUtterance
            let timeline: Timeline

            init() throws {
                sentText = try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T12:11:00+09:00")
                next = try .fixture("ありがとう", sentAt: "2026-09-24T12:30:00+09:00")
                reply = AiUtterance(
                    id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: sentText.id, mealIds: [])
                timeline = PlacingConversation.timeline(
                    conversation: Timeline.Conversation(
                        sentTexts: [next, sentText],
                        statuses: [
                            sentText.id: SentTextStatus(
                                classification: .conversation, reply: .replied),
                            next.id: SentTextStatus(
                                classification: .conversation, reply: .halted),
                        ],
                        replies: [reply], streams: [:]))
            }

            @Test("返事を、応える文章のすぐあとに並べること")
            func placesReplyRightAfterSentText() {
                #expect(
                    timeline.days.map { $0.items.map(\.id) } == [
                        [
                            "sent-text-\(sentText.id.uuidString)",
                            "reply-\(reply.id.uuidString)",
                            "sent-text-\(next.id.uuidString)",
                        ]
                    ])
            }
        }

        @Suite("送った文章より先に返事が届いたとき")
        struct ReplyBeforeSentText {
            let timeline: Timeline

            init() {
                timeline = PlacingConversation.timeline(
                    conversation: Timeline.Conversation(
                        sentTexts: [],
                        statuses: [:],
                        replies: [
                            AiUtterance(id: UUID(), body: "どうぞ", sentTextId: UUID(), mealIds: [])
                        ], streams: [:]))
            }

            @Test("送った文章が届くまで、返事を出さないこと")
            func hidesReply() {
                #expect(timeline.days.map(\.items) == [[]])
            }
        }
    }
}
