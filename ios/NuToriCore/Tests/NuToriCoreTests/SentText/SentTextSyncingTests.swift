import Foundation
import NuToriAPI
import NuToriCore
import Testing

/// 送り直す2つの書き込みは、サーバーの API に形が入るまで送らない（同期の働きから断られない）ので、種類の扱いを直に確かめる
@Suite("送った文章の、受け付けなかった送り直す書き込みの扱い")
struct SentTextSyncingTests {
    @Suite("サーバーに文章があるとき")
    struct ServerHasSentText {
        let sentText: SentText
        let current: SyncWriteResult.Current

        init() throws {
            sentText = SentText(
                id: UUID(), body: "朝はパン、昼はうどん",
                sentAt: Date(timeIntervalSince1970: 1_790_046_660),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
            current = .value(
                .sentText(
                    SyncedSentText(
                        id: sentText.id, body: sentText.body, sentAt: sentText.sentAt,
                        timeZone: sentText.timeZone)))
        }

        @Test("会話として送り直す書き込みは、会話として送り直せなかった行を出し、キャッシュから外さないこと")
        func resendAsConversation() throws {
            let rejection = try SentTextSyncing().rejection(
                of: try entry(.resendAsConversation(sentTextId: sentText.id)),
                reason: .notClassifiedAsMeal, current: current, shown: .none)

            #expect(
                rejection.rejectedWrite?.record
                    == .sentText(
                        RejectedSentTextLine(sentText: sentText, subject: .resendAsConversation)))
            #expect(rejection.removingChanges.isEmpty)
        }

        @Test("送り直す書き込みは、送り直せなかった行を出し、キャッシュから外さないこと")
        func resend() throws {
            let rejection = try SentTextSyncing().rejection(
                of: try entry(.resend(sentTextId: sentText.id)),
                reason: .replyNotFailed, current: current, shown: .none)

            #expect(
                rejection.rejectedWrite?.record
                    == .sentText(RejectedSentTextLine(sentText: sentText, subject: .resend)))
            #expect(rejection.removingChanges.isEmpty)
        }
    }

    @Suite("サーバーに文章が無いとき")
    struct ServerLacksSentText {
        let sentTextId = UUID()

        @Test("送り直す書き込みは、行を出さず、文章をキャッシュから外すこと")
        func resend() throws {
            let rejection = try SentTextSyncing().rejection(
                of: try entry(.resend(sentTextId: sentTextId)),
                reason: .recordNotFound, current: .absent, shown: .none)

            #expect(rejection.rejectedWrite == nil)
            #expect(rejection.removingChanges == [.sentTextRemoval(sentTextId: sentTextId)])
        }
    }
}

private func entry(_ write: SentTextWrite) throws -> PendingEntry {
    try PendingSentTextWrite(enqueuedAt: Date(timeIntervalSince1970: 1_790_046_700), write: write)
        .entry()
}
