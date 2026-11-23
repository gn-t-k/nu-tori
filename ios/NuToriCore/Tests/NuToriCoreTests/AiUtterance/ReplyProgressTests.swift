import Foundation
import NuToriCore
import Testing

@Suite("待っていた返事の結果が出たか")
struct ReplyProgressTests {
    static func bubble(_ sentText: SentText, _ replyLine: SentTextBubble.ReplyLine?)
        -> Timeline.Item
    {
        .sentText(
            SentTextBubble(sentText: sentText, meals: [], replyLine: replyLine, rejectedLine: nil))
    }

    static func reply(to sentText: SentText, body: String) -> Timeline.Item {
        .reply(
            TimelineReply(
                id: UUID(), sentTextId: sentText.id, body: body, isGrowing: true,
                referencedMeals: []))
    }

    @Suite("返事を待っていた文章")
    struct WasReading {
        let sentText: SentText
        let earlier: ReplyProgress

        init() throws {
            sentText = try .fixture("今日の夕食は何がいい？", sentAt: "2026-09-24T12:10:00+09:00")
            earlier = ReplyProgress(items: [ReplyProgressTests.bubble(sentText, .reading)])
        }

        @Test("返事の最初の文字が届いたら、返事が届いたとすること")
        func replied() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, nil),
                ReplyProgressTests.reply(to: sentText, body: "鍋"),
            ])
            #expect(now.hasReplied(since: earlier))
        }

        @Test("返事がまだ空なら、返事が届いたとしないこと")
        func emptyReply() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .reading),
                ReplyProgressTests.reply(to: sentText, body: ""),
            ])
            #expect(!now.hasReplied(since: earlier))
        }

        @Test("返事を作れなかったら、作れなかったとすること")
        func failed() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .failed(.retriesExhausted))
            ])
            #expect(now.hasFailed(since: earlier))
        }

        @Test("返事を止めたら、作れなかったとすること")
        func halted() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .halted(.dailyLimit))
            ])
            #expect(now.hasFailed(since: earlier))
        }

        @Test("返事を作れなかったら、返事が届いたとしないこと")
        func failedIsNotReplied() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .failed(.retriesExhausted))
            ])
            #expect(!now.hasReplied(since: earlier))
        }

        @Test("食事と読み分けて1行が外れても、返事が届いたとも作れなかったともしないこと")
        func readAsMeal() {
            let now = ReplyProgress(items: [ReplyProgressTests.bubble(sentText, nil)])
            #expect(!now.hasReplied(since: earlier))
            #expect(!now.hasFailed(since: earlier))
        }
    }

    @Suite("開いたときに最初から結果が出ていた文章")
    struct AlreadySettled {
        let sentText: SentText
        let earlier: ReplyProgress

        init() throws {
            sentText = try .fixture("今日の夕食は何がいい？", sentAt: "2026-09-24T12:10:00+09:00")
            earlier = ReplyProgress(items: [])
        }

        @Test("返事があっても、返事が届いたとしないこと")
        func replied() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, nil),
                ReplyProgressTests.reply(to: sentText, body: "鍋"),
            ])
            #expect(!now.hasReplied(since: earlier))
        }

        @Test("作れなかった1行があっても、作れなかったとしないこと")
        func failed() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .failed(.retriesExhausted))
            ])
            #expect(!now.hasFailed(since: earlier))
        }
    }

    @Suite("作れなかった返事を送り直して、また待っている文章")
    struct Resent {
        let sentText: SentText
        let earlier: ReplyProgress

        init() throws {
            sentText = try .fixture("今日の夕食は何がいい？", sentAt: "2026-09-24T12:10:00+09:00")
            earlier = ReplyProgress(items: [ReplyProgressTests.bubble(sentText, .reading)])
        }

        @Test("また作れなかったら、作れなかったとすること")
        func failedAgain() {
            let now = ReplyProgress(items: [
                ReplyProgressTests.bubble(sentText, .failed(.badRequest))
            ])
            #expect(now.hasFailed(since: earlier))
        }
    }
}
