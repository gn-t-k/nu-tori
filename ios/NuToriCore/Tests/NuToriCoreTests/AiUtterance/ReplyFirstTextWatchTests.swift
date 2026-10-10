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

    @Suite("読んでいますを出したあと、見守る要求で最初の文字が出たとき")
    struct Streamed {
        let sentText: SentText
        let replyId = UUID()
        let watch: ReplyFirstTextWatch
        let firstEvents: [ClientUsageEvent]

        init() throws {
            sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            var watch = ReplyFirstTextWatch()
            firstEvents = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: ReplyFirstTextWatchTests.awaiting),
                at: ReplyFirstTextWatchTests.start)
            self.watch = watch
        }

        @Test("読んでいますを出してから最初の文字が出るまでの秒数を、つながっていたとして送ること")
        func reportsStreamedFirstText() {
            var watch = watch
            let shown = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: ReplyFirstTextWatchTests.awaiting,
                    stream: [ReplyStreamEvent.replyStarted(replyId: replyId), .textDelta("野菜")]
                        .reduce(into: ReplyStream()) { $0.receive($1) }),
                at: ReplyFirstTextWatchTests.start.addingTimeInterval(6))

            #expect(firstEvents.isEmpty)
            #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(6), watched: true)])
        }
    }

    @Suite("読んでいますを出したあと、取りに行って返事が届いたとき")
    struct Pulled {
        let sentText: SentText
        let reply: AiUtterance
        let watch: ReplyFirstTextWatch

        init() throws {
            sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            reply = AiUtterance(
                id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
            var watch = ReplyFirstTextWatch()
            _ = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: ReplyFirstTextWatchTests.awaiting),
                at: ReplyFirstTextWatchTests.start)
            self.watch = watch
        }

        @Test("つながっていなかったとして、1回だけ送ること")
        func reportsPulledReplyOnce() {
            var watch = watch
            let replied = ReplyFirstTextWatchTests.timeline(
                sentText, status: ReplyFirstTextWatchTests.replied, replies: [reply])
            let shown = watch.note(
                replied, at: ReplyFirstTextWatchTests.start.addingTimeInterval(9))
            let again = watch.note(
                replied, at: ReplyFirstTextWatchTests.start.addingTimeInterval(12))

            #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(9), watched: false)])
            #expect(again.isEmpty)
        }
    }

    @Suite("開いたときにもう返事が届いていたとき")
    struct AlreadyReplied {
        let timeline: Timeline

        init() throws {
            let sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            let reply = AiUtterance(
                id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
            timeline = ReplyFirstTextWatchTests.timeline(
                sentText, status: ReplyFirstTextWatchTests.replied, replies: [reply])
        }

        @Test("送らないこと")
        func ignoresRepliesAlreadyShown() {
            var watch = ReplyFirstTextWatch()
            #expect(watch.note(timeline, at: ReplyFirstTextWatchTests.start).isEmpty)
        }
    }

    @Suite("まだ届いていない文章を送り待ちに並べたのを見てから、返事が届いたとき")
    struct FromUndelivered {
        let sentText: SentText
        let reply: AiUtterance
        let watch: ReplyFirstTextWatch

        init() throws {
            sentText = try SentText.fixture("次は？", sentAt: "2026-09-24T12:11:00+09:00")
            reply = AiUtterance(
                id: UUID(), body: "野菜を足しましょう。", sentTextId: sentText.id, mealIds: [])
            let undelivered = UndeliveredRecords(pendingEntries: [
                try PendingSentTextWrite(
                    enqueuedAt: ReplyFirstTextWatchTests.start, write: .create(sentText)
                ).entry()
            ])
            var watch = ReplyFirstTextWatch()
            _ = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: nil, undelivered: undelivered),
                at: ReplyFirstTextWatchTests.start)
            _ = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: ReplyFirstTextWatchTests.awaiting),
                at: ReplyFirstTextWatchTests.start.addingTimeInterval(2))
            self.watch = watch
        }

        @Test("送り待ちに並べたのを見た時点から数えること")
        func countsFromUndelivered() {
            var watch = watch
            let shown = watch.note(
                ReplyFirstTextWatchTests.timeline(
                    sentText, status: ReplyFirstTextWatchTests.replied, replies: [reply]),
                at: ReplyFirstTextWatchTests.start.addingTimeInterval(5))

            #expect(shown == [.replyFirstTextShown(sinceSent: .seconds(5), watched: false)])
        }
    }

    @Suite("応答を待つのを見たあと、食事と読み分けたか、作れなかったとき")
    struct NotReplied {
        let meal: SentText
        let failed: SentText
        let mealWatch: ReplyFirstTextWatch
        let failedWatch: ReplyFirstTextWatch

        init() throws {
            meal = try SentText.fixture("昼はうどん", sentAt: "2026-09-24T12:11:00+09:00")
            failed = try SentText.fixture("次は？", sentAt: "2026-09-24T12:12:00+09:00")
            var mealWatch = ReplyFirstTextWatch()
            var failedWatch = ReplyFirstTextWatch()
            _ = mealWatch.note(
                ReplyFirstTextWatchTests.timeline(meal, status: nil),
                at: ReplyFirstTextWatchTests.start)
            _ = failedWatch.note(
                ReplyFirstTextWatchTests.timeline(
                    failed, status: ReplyFirstTextWatchTests.awaiting),
                at: ReplyFirstTextWatchTests.start)
            self.mealWatch = mealWatch
            self.failedWatch = failedWatch
        }

        @Test("送らないこと")
        func ignoresMealsAndFailures() {
            var mealWatch = mealWatch
            var failedWatch = failedWatch
            let later = ReplyFirstTextWatchTests.start.addingTimeInterval(3)
            let events =
                mealWatch.note(
                    ReplyFirstTextWatchTests.timeline(
                        meal, status: SentTextStatus(classification: .meal, reply: .notRequested)),
                    at: later)
                + failedWatch.note(
                    ReplyFirstTextWatchTests.timeline(
                        failed,
                        status: SentTextStatus(
                            classification: .conversation, reply: .failed(.retriesExhausted))),
                    at: later)

            #expect(events.isEmpty)
        }
    }
}
