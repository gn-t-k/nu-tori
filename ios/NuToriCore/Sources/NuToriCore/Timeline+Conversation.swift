public import Foundation

extension Timeline {
    /// タイムラインに並べる会話の元。送った文章、その状態、返事、見守る要求で受け取っている途中の返事
    public struct Conversation: Sendable {
        public static let none = Conversation(sentTexts: [], statuses: [:])

        public let sentTexts: [SentText]
        /// 送った文章の ID ごとの状態。送った文章より先に届いた状態も含む
        public let statuses: [UUID: SentTextStatus]
        /// 送った文章より先に届いた返事も含む。送った文章が届くまで出さない
        public let replies: [AiUtterance]
        /// 送った文章の ID ごとの、見守る要求で受け取っている途中の返事（`ReplyWatches`）
        public let streams: [UUID: ReplyStream]

        public init(
            sentTexts: [SentText],
            statuses: [UUID: SentTextStatus],
            replies: [AiUtterance] = [],
            streams: [UUID: ReplyStream] = [:]
        ) {
            self.sentTexts = sentTexts
            self.statuses = statuses
            self.replies = replies
            self.streams = streams
        }

        /// 応答を待つ送った文章。届いていて（送り待ちに書き込みが無く）、応答（文章の食事、返事、作れなかった・回数切れ）の
        /// 状態がまだ届いていない文章。見守る要求をつなぎ、つながっていなければ送ってから1分まで数秒おきに取りに行く
        public func sentTextIdsAwaitingResponse(undelivered: UndeliveredRecords) -> Set<UUID> {
            Set(
                sentTexts.map(\.id).filter {
                    !undelivered.containsSentText(id: $0) && Self.awaitsResponse(statuses[$0])
                })
        }

        static func awaitsResponse(_ status: SentTextStatus?) -> Bool {
            guard let status else { return true }
            switch (status.classification, status.reply) {
            case (.pending, _), (.conversation, .notRequested), (.conversation, .awaiting):
                return true
            case (.meal, _), (.conversation, .replied), (.conversation, .halted),
                (.conversation, .failed):
                return false
            }
        }
    }

    /// 会話の元から作る、タイムラインに置くもの
    struct ConversationItems {
        let bubbles: [SentTextBubble]
        /// 送った文章の ID ごとの返事。送った文章が届いていない返事は入らない
        let replies: [UUID: [TimelineReply]]
        /// 吹き出しに添えず、それだけを置く受け付けなかった1行（文章を送れなかった）
        let separateLines: [RejectedSentTextLine]

        init(
            _ conversation: Conversation,
            rejectedLines: [RejectedSentTextLine],
            cardsByMealId: [UUID: MealCard],
            undelivered: UndeliveredRecords
        ) {
            let sentTextIds = Set(conversation.sentTexts.map(\.id))
            let linesBelowBubble = Dictionary(
                rejectedLines.filter {
                    $0.placement == .belowBubble && sentTextIds.contains($0.sentText.id)
                }.map { ($0.sentText.id, $0) },
                uniquingKeysWith: { _, latest in latest })
            separateLines = rejectedLines.filter { linesBelowBubble[$0.sentText.id] != $0 }
            let replyIds = Set(conversation.replies.map(\.id))
            let records = conversation.replies.filter { sentTextIds.contains($0.sentTextId) }.map {
                TimelineReply(
                    id: $0.id, sentTextId: $0.sentTextId, body: $0.body, isGrowing: false,
                    referencedMeals: $0.mealIds.map { mealId in
                        cardsByMealId[mealId].map { .meal($0) } ?? .deleted(mealId: mealId)
                    })
            }
            // 見守る要求で届いた ID と同じ返事が届いたら、届いた返事で置き換える
            let growing = conversation.streams.compactMap { sentTextId, stream in
                sentTextIds.contains(sentTextId)
                    ? stream.growingReply(sentTextId: sentTextId) : nil
            }.filter { !replyIds.contains($0.id) }
            let replies = Dictionary(grouping: records + growing, by: \.sentTextId)
            self.replies = replies
            bubbles = conversation.sentTexts.map { sentText in
                SentTextBubble(
                    sentText: sentText,
                    replyLine: undelivered.containsSentText(id: sentText.id)
                        ? nil
                        : Self.replyLine(
                            status: conversation.statuses[sentText.id],
                            hasReply: replies[sentText.id]?.contains { !$0.body.isEmpty } ?? false
                        ),
                    rejectedLine: linesBelowBubble[sentText.id])
            }
        }

        /// 応答待ちは、応答（文章の食事、返事の最初の文字、作れなかった・回数切れ）がまだ届いていないあいだ。
        /// 送り直した文章は、書き込みが届くまで前の1行を外し、回る印も出さない（呼び出し側が、まだ届いていない文章を除く）
        private static func replyLine(status: SentTextStatus?, hasReply: Bool)
            -> SentTextBubble.ReplyLine?
        {
            guard !hasReply else { return nil }
            guard let status, !Conversation.awaitsResponse(status) else { return .reading }
            switch (status.classification, status.reply) {
            case (.meal, _): return nil
            case (.conversation, .halted): return .halted
            case (.conversation, .failed(let reason)): return .failed(reason)
            // 返事ありの状態が返事の記録より先に届いた一瞬と、届くことのない組み合わせ
            case (.conversation, _), (.pending, _): return .reading
            }
        }
    }
}

extension Timeline {
    /// 見守る要求で伸びている途中の返事があるか。あるあいだは、タイムラインの一番下へ追う
    public var hasGrowingReply: Bool {
        days.contains { day in
            day.items.contains { item in
                if case .reply(let reply) = item { reply.isGrowing } else { false }
            }
        }
    }
}

extension SentText {
    /// タイムラインに吹き出しを置く日。送った時刻と、送ったときのタイムゾーンで決める
    public var day: CalendarDay {
        CalendarDay(containing: sentAt, in: timeZone)
    }
}
