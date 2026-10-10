import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("応答を待つ送った文章")
struct AwaitingResponseTests {
    @Suite("届いていて応答がまだ届いていない文章と、ほかの文章があるとき")
    struct Mixed {
        let waiting: [SentText]
        let settled: [SentText]
        let undelivered: SentText
        let conversation: Timeline.Conversation
        let pending: UndeliveredRecords

        init() throws {
            waiting = try (0..<3).map { _ in
                try SentText.fixture(sentAt: "2026-09-24T12:00:00+09:00")
            }
            settled = try (0..<4).map { _ in
                try SentText.fixture(sentAt: "2026-09-24T12:00:00+09:00")
            }
            undelivered = try SentText.fixture(sentAt: "2026-09-24T12:00:00+09:00")
            let statuses: [SentTextStatus?] = [
                nil,
                SentTextStatus(classification: .pending, reply: .notRequested),
                SentTextStatus(classification: .conversation, reply: .awaiting),
            ]
            let settledStatuses = [
                SentTextStatus(classification: .meal, reply: .notRequested),
                SentTextStatus(classification: .conversation, reply: .replied),
                SentTextStatus(classification: .conversation, reply: .halted),
                SentTextStatus(classification: .conversation, reply: .failed(.badRequest)),
            ]
            var byId: [UUID: SentTextStatus] = [:]
            for (text, status) in zip(waiting, statuses) { byId[text.id] = status }
            for (text, status) in zip(settled, settledStatuses) { byId[text.id] = status }
            conversation = Timeline.Conversation(
                sentTexts: waiting + settled + [undelivered], statuses: byId)
            pending = UndeliveredRecords(pendingEntries: [
                try PendingSentTextWrite(
                    enqueuedAt: undelivered.sentAt, write: .create(undelivered)
                ).entry()
            ])
        }

        @Test("読み分けを待つ文章と返事を待つ文章だけを、応答を待つ文章とすること")
        func onlyWaitingTexts() {
            #expect(
                conversation.sentTextIdsAwaitingResponse(undelivered: pending)
                    == Set(waiting.map(\.id)))
        }
    }
}
