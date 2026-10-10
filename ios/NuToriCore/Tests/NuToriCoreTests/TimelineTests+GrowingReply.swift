import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("見守る要求で伸びている返事")
    struct GrowingReply {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        static func items(
            sentText: SentText, stream: ReplyStream, replies: [AiUtterance] = []
        ) -> [Timeline.Item] {
            Timeline(
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [], meals: [], notices: [],
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText],
                        statuses: [
                            sentText.id: SentTextStatus(
                                classification: .conversation, reply: .awaiting)
                        ],
                        replies: replies,
                        streams: [sentText.id: stream])),
                firstDay: day, today: day
            ).days.flatMap(\.items)
        }

        static func stream(_ events: [ReplyStreamEvent]) -> ReplyStream {
            events.reduce(into: ReplyStream()) { $0.receive($1) }
        }

        @Test("最初の文字が届いたら、読んでいますを文に置き換え、文章のすぐあとに伸びている返事を置くこと")
        func showsGrowingReply() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let replyId = UUID()
            let items = Self.items(
                sentText: sentText,
                stream: Self.stream([
                    .replyStarted(replyId: replyId), .textDelta("野菜の"), .textDelta("多い"),
                ]))
            #expect(
                items == [
                    .sentText(SentTextBubble(sentText: sentText, replyLine: nil)),
                    .reply(
                        TimelineReply(
                            id: replyId, sentTextId: sentText.id, body: "野菜の多い", isGrowing: true,
                            referencedMeals: [])),
                ])
        }

        @Test("最初の文字が届くまでと、流し直しの知らせで捨てたあとは、読んでいますを出すこと")
        func showsReadingWithoutText() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let replyId = UUID()
            for stream in [
                Self.stream([.replyStarted(replyId: replyId)]),
                Self.stream([.replyStarted(replyId: replyId), .textDelta("野菜の"), .textDiscarded]),
            ] {
                #expect(
                    Self.items(sentText: sentText, stream: stream) == [
                        .sentText(SentTextBubble(sentText: sentText, replyLine: .reading))
                    ])
            }
        }

        @Test("同じ ID の返事が届いたら、届いた返事で置き換えること")
        func replacesWithRecord() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let reply = AiUtterance(
                id: UUID(), body: "野菜の多い定食はどうでしょう。", sentTextId: sentText.id, mealIds: [])
            let items = Self.items(
                sentText: sentText,
                stream: Self.stream([.replyStarted(replyId: reply.id), .textDelta("野菜の")]),
                replies: [reply])
            #expect(
                items.compactMap { item -> TimelineReply? in
                    if case .reply(let reply) = item { reply } else { nil }
                } == [
                    TimelineReply(
                        id: reply.id, sentTextId: sentText.id, body: reply.body, isGrowing: false,
                        referencedMeals: [])
                ])
        }

        @Test("伸びている返事があるあいだだけ、伸びている返事があるとすること")
        func tellsWhetherAReplyIsGrowing() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let replyId = UUID()
            func timeline(_ stream: ReplyStream, replies: [AiUtterance] = []) -> Timeline {
                Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [],
                        conversation: Timeline.Conversation(
                            sentTexts: [sentText],
                            statuses: [
                                sentText.id: SentTextStatus(
                                    classification: .conversation, reply: .awaiting)
                            ],
                            replies: replies,
                            streams: [sentText.id: stream])),
                    firstDay: Self.day, today: Self.day)
            }
            let growing = Self.stream([.replyStarted(replyId: replyId), .textDelta("野菜の")])
            let reply = AiUtterance(
                id: replyId, body: "野菜の多い定食はどうでしょう。", sentTextId: sentText.id, mealIds: [])

            #expect(
                timeline(Self.stream([.replyStarted(replyId: replyId)])).hasGrowingReply == false)
            #expect(timeline(growing).hasGrowingReply)
            #expect(timeline(growing, replies: [reply]).hasGrowingReply == false)
        }
    }
}
