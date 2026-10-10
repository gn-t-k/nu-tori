import Foundation
import NuToriCore
import Testing

extension ClientUsageEventTests {
    @Suite("食事のカードの「会話として送り直す」を押したとき")
    struct ResentAsConversation {
        @Test("消えた食事の数だけを載せること")
        func carriesDeletedMealCount() {
            let event = ClientUsageEvent.resentAsConversation(deletedMealCount: 2)

            #expect(event.name == "resent_as_conversation")
            #expect(event.fields == ["deleted_meal_count": .count(2)])
            #expect(event.screenToken == nil)
        }
    }

    @Suite("作れなかった・回数切れの1行の「送り直す」を押したとき")
    struct ReplyRegenerateTapped {
        @Test("やり直しを使い切った・400・回数切れを理由として載せること")
        func carriesReason() {
            let events: [ClientUsageEvent] = [
                .replyRegenerateTapped(.failed(.retriesExhausted)),
                .replyRegenerateTapped(.failed(.badRequest)),
                .replyRegenerateTapped(.halted),
            ]

            #expect(events.map(\.name) == Array(repeating: "reply_regenerate_tapped", count: 3))
            #expect(
                events.map(\.fields) == [
                    ["reason": .token("retries_exhausted")],
                    ["reason": .token("bad_request")],
                    ["reason": .token("halted")],
                ])
        }
    }

    @Suite("返事の最初の文字を出したとき")
    struct ReplyFirstTextShown {
        @Test("最初の文字が出るまでの秒数と、見守る要求でつながっていたかを載せること")
        func carriesSecondsAndWatched() {
            let event = ClientUsageEvent.replyFirstTextShown(
                sinceSent: .milliseconds(4_800), watched: true)

            #expect(event.name == "reply_first_text_shown")
            #expect(
                event.fields == ["seconds_since_sent": .wholeSeconds(4), "watched": .flag(true)])
            #expect(event.screenToken == nil)
        }
    }

    @Suite("返事の下の指し示す食事を押したとき")
    struct ReplyMealOpened {
        @Test("押したことだけを数えること")
        func hasNoFields() {
            let event = ClientUsageEvent.replyMealOpened

            #expect(event.name == "reply_meal_opened")
            #expect(event.fields.isEmpty)
            #expect(event.screenToken == nil)
        }
    }
}
