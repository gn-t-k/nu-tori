import Foundation
import NuToriAPI
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("吹き出しの下の応答の1行")
    struct ReplyLines {
        static let day = CalendarDay(year: 2026, month: 9, day: 24)

        /// 1つの送った文章の吹き出し
        static func bubble(
            status: SentTextStatus?,
            replies: [AiUtterance] = [],
            pending: [SentTextWrite] = [],
            sentText: SentText
        ) throws -> SentTextBubble? {
            let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [], meals: [], notices: [],
                    undelivered: UndeliveredRecords(
                        pendingEntries: try pending.map {
                            try PendingSentTextWrite(enqueuedAt: sentText.sentAt, write: $0).entry()
                        }),
                    conversation: Timeline.Conversation(
                        sentTexts: [sentText],
                        statuses: status.map { [sentText.id: $0] } ?? [:],
                        replies: replies)),
                firstDay: day, today: day)
            return timeline.days.flatMap(\.items).lazy.compactMap { item in
                if case .sentText(let bubble) = item { bubble } else { nil }
            }.first
        }

        static func sentText() throws -> SentText {
            try .fixture("次は何を食べたらいい？", sentAt: "2026-09-24T12:11:00+09:00")
        }

        @Suite("応答待ち")
        struct Reading {
            @Test("届いて状態がまだ無いあいだは、送り直すを添えずに読んでいますを出すこと")
            func showsReadingWithoutStatus() throws {
                let line = try ReplyLines.bubble(status: nil, sentText: ReplyLines.sentText())?
                    .replyLine
                #expect(line == .reading)
                #expect(line?.text == "読んでいます…")
                #expect(line?.offersResend == false)
            }

            @Test("読み分けを待つあいだは、読んでいますを出すこと")
            func showsReadingWhileClassifying() throws {
                let line = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .pending, reply: .notRequested),
                    sentText: ReplyLines.sentText())?.replyLine
                #expect(line == .reading)
            }

            @Test("会話と読み分けて返事を待つあいだは、読んでいますを出すこと")
            func showsReadingWhileAwaitingReply() throws {
                let line = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .conversation, reply: .awaiting),
                    sentText: ReplyLines.sentText())?.replyLine
                #expect(line == .reading)
            }

            @Test("まだ届いていない文章では、出さないこと")
            func hidesWhileUndelivered() throws {
                let sentText = try ReplyLines.sentText()
                let bubble = try ReplyLines.bubble(
                    status: nil, pending: [.create(sentText)], sentText: sentText)
                #expect(bubble == SentTextBubble(sentText: sentText, replyLine: nil))
            }

            @Test("返事が届いたら、出さないこと")
            func hidesAfterReply() throws {
                let sentText = try ReplyLines.sentText()
                let bubble = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .conversation, reply: .replied),
                    replies: [
                        AiUtterance(id: UUID(), body: "どうぞ", sentTextId: sentText.id, mealIds: [])
                    ],
                    sentText: sentText)
                #expect(bubble?.replyLine == nil)
            }

            @Test("食事と読み分けたら、出さないこと")
            func hidesForMeal() throws {
                let bubble = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .meal, reply: .notRequested),
                    sentText: ReplyLines.sentText())
                #expect(bubble?.replyLine == nil)
            }
        }

        @Suite("作れなかった・回数切れ")
        struct NotReplied {
            static func line(_ reply: SentTextStatus.Reply) throws -> SentTextBubble.ReplyLine? {
                try ReplyLines.bubble(
                    status: SentTextStatus(classification: .conversation, reply: reply),
                    sentText: ReplyLines.sentText())?.replyLine
            }

            @Test("回数切れは、今日はもう返事を作れませんの1行に送り直すを添えること")
            func showsHalted() throws {
                let line = try Self.line(.halted)
                #expect(line?.text == "今日はもう返事を作れません")
                #expect(line?.offersResend == true)
            }

            @Test("やり直しを使い切ったら、返事を作れませんでしたの1行に送り直すを添えること")
            func showsRetriesExhausted() throws {
                let line = try Self.line(.failed(.retriesExhausted))
                #expect(line?.text == "返事を作れませんでした")
                #expect(line?.offersResend == true)
            }

            @Test("提供元が受け付けなかったら、時間をおいて送り直すよう促す1行に送り直すを添えること")
            func showsBadRequest() throws {
                let line = try Self.line(.failed(.badRequest))
                #expect(line?.text == "今は返事を作れません。時間をおいて送り直してください")
                #expect(line?.offersResend == true)
            }
        }

        @Suite("送り直したとき")
        struct Resent {
            @Test("送り直すの書き込みが届くまで、前の1行を外し、読んでいますも出さないこと")
            func hidesPreviousLineWhileResending() throws {
                let sentText = try ReplyLines.sentText()
                let bubble = try ReplyLines.bubble(
                    status: SentTextStatus(
                        classification: .conversation, reply: .failed(.retriesExhausted)),
                    pending: [.resend(sentTextId: sentText.id)], sentText: sentText)
                #expect(bubble?.replyLine == nil)
            }

            @Test("会話として送り直すの書き込みが届くまで、読んでいますを出さないこと")
            func hidesReadingWhileResendingAsConversation() throws {
                let sentText = try ReplyLines.sentText()
                let bubble = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .meal, reply: .notRequested),
                    pending: [.resendAsConversation(sentTextId: sentText.id)],
                    sentText: sentText)
                #expect(bubble?.replyLine == nil)
            }

            @Test("書き込みが届いて応答待ちになったら、読んでいますを出すこと")
            func showsReadingAfterDelivered() throws {
                let bubble = try ReplyLines.bubble(
                    status: SentTextStatus(classification: .conversation, reply: .awaiting),
                    sentText: ReplyLines.sentText())
                #expect(bubble?.replyLine == .reading)
            }
        }
    }
}
