import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("返事の最初の文字を出したときの出来事")
struct ReplyFirstTextWatchTests {
    static let day = CalendarDay(year: 2026, month: 9, day: 24)
    static let start = Date(timeIntervalSince1970: 1_790_000_000)

    static func timeline(
        _ sentText: SentText,
        status: SentTextStatus?,
        replies: [AiUtterance] = [],
        stream: ReplyStream? = nil,
        undelivered: UndeliveredRecords = .none
    ) -> Timeline {
        Timeline(
            input: Timeline.Input(
                weightRecords: [], rejectedLines: [], meals: [], notices: [],
                undelivered: undelivered,
                conversation: Timeline.Conversation(
                    sentTexts: [sentText],
                    statuses: status.map { [sentText.id: $0] } ?? [:],
                    replies: replies,
                    streams: stream.map { [sentText.id: $0] } ?? [:])),
            firstDay: day, today: day)
    }

    static let awaiting = SentTextStatus(classification: .conversation, reply: .awaiting)
    static let replied = SentTextStatus(classification: .conversation, reply: .replied)

    @Test("読んでいますを出してから、見守る要求で最初の文字が出るまでの秒数を、つながっていたとして送ること")
    func reportsStreamedFirstText() throws {
        let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
        let replyId = UUID()
        var watch = ReplyFirstTextWatch()

        let first = watch.note(Self.timeline(sentText, status: Self.awaiting), at: Self.start)
        let shown = watch.note(
            Self.timeline(
                sentText, status: Self.awaiting,
                stream: [ReplyStreamEvent.replyStarted(replyId: replyId), .textDelta("野菜")]
                    .reduce(into: ReplyStream()) { $0.receive($1) }),
            at: Self.start.addingTimeInterval(6))

        #expect(first.isEmpty)
        #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(6), watched: true)])
    }

    @Test("取りに行って届いた返事は、つながっていなかったとして、1回だけ送ること")
    func reportsPulledReplyOnce() throws {
        let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
        let reply = AiUtterance(
            id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
        var watch = ReplyFirstTextWatch()

        _ = watch.note(Self.timeline(sentText, status: Self.awaiting), at: Self.start)
        let shown = watch.note(
            Self.timeline(sentText, status: Self.replied, replies: [reply]),
            at: Self.start.addingTimeInterval(9))
        let again = watch.note(
            Self.timeline(sentText, status: Self.replied, replies: [reply]),
            at: Self.start.addingTimeInterval(12))

        #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(9), watched: false)])
        #expect(again.isEmpty)
    }

    @Test("開いたときにもう届いていた返事は送らないこと")
    func ignoresRepliesAlreadyShown() throws {
        let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
        let reply = AiUtterance(
            id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
        var watch = ReplyFirstTextWatch()

        let events = watch.note(
            Self.timeline(sentText, status: Self.replied, replies: [reply]), at: Self.start)

        #expect(events.isEmpty)
    }

    @Test("まだ届いていない文章を送り待ちに並べた時点から数えること")
    func countsFromUndelivered() throws {
        let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
        let reply = AiUtterance(
            id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
        let undelivered = UndeliveredRecords(pendingEntries: [
            try PendingSentTextWrite(enqueuedAt: Self.start, write: .create(sentText)).entry()
        ])
        var watch = ReplyFirstTextWatch()

        _ = watch.note(
            Self.timeline(sentText, status: nil, undelivered: undelivered), at: Self.start)
        _ = watch.note(
            Self.timeline(sentText, status: Self.awaiting), at: Self.start.addingTimeInterval(2))
        let shown = watch.note(
            Self.timeline(sentText, status: Self.replied, replies: [reply]),
            at: Self.start.addingTimeInterval(5))

        #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(5), watched: false)])
    }

    @Test("食事と読み分けた文章と、作れなかった文章は送らないこと")
    func ignoresMealsAndFailures() throws {
        let meal = try SentText.fixture("昼はうどん", sentAt: "2026-09-24T12:11:00+09:00")
        let failed = try SentText.fixture("次は？", sentAt: "2026-09-24T12:12:00+09:00")
        var mealWatch = ReplyFirstTextWatch()
        var failedWatch = ReplyFirstTextWatch()

        _ = mealWatch.note(Self.timeline(meal, status: nil), at: Self.start)
        _ = failedWatch.note(Self.timeline(failed, status: Self.awaiting), at: Self.start)
        let events =
            mealWatch.note(
                Self.timeline(
                    meal, status: SentTextStatus(classification: .meal, reply: .notRequested)),
                at: Self.start.addingTimeInterval(3))
            + failedWatch.note(
                Self.timeline(
                    failed,
                    status: SentTextStatus(
                        classification: .conversation, reply: .failed(.retriesExhausted))),
                at: Self.start.addingTimeInterval(3))

        #expect(events.isEmpty)
    }
}
