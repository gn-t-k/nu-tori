import Foundation
import NuToriCore
import Testing

@Suite("答えていない知らせの1行")
struct UnansweredNoticeLineTests {
    static func card(form: NoticeCard.Form) throws -> NoticeCard {
        let today = CalendarDay(year: 2026, month: 9, day: 22)
        return NoticeCard(
            notice: Notice(
                id: Notice.id(kind: .missedWeightRecord, targetDay: today),
                kind: .missedWeightRecord,
                issuedAt: try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                targetDay: today,
                response: nil
            ),
            form: form
        )
    }

    @Suite("今日の答えていない知らせのカードが、画面の上へ流れたとき")
    struct ScrolledAbove {
        let card: NoticeCard
        let line: UnansweredNoticeLine

        init() throws {
            card = try UnansweredNoticeLineTests.card(form: .awaitingAnswer)
            var line = UnansweredNoticeLine()
            line.note(.init(noticeId: card.notice.id, maxY: -20))
            self.line = line
        }

        @Test("出すこと")
        func shows() {
            #expect(line.shows(for: card))
        }
    }

    @Suite("上へ流れたあと、遠くまで送ってカードが描かれなくなったとき")
    struct ScrolledFarAbove {
        let card: NoticeCard
        let line: UnansweredNoticeLine

        init() throws {
            card = try UnansweredNoticeLineTests.card(form: .awaitingAnswer)
            var line = UnansweredNoticeLine()
            line.note(.init(noticeId: card.notice.id, maxY: -20))
            line.note(nil)
            self.line = line
        }

        @Test("出したままにすること")
        func keepsShowing() {
            #expect(line.shows(for: card))
        }
    }

    @Suite("カードが画面に見えているとき")
    struct Visible {
        let card: NoticeCard
        let line: UnansweredNoticeLine

        init() throws {
            card = try UnansweredNoticeLineTests.card(form: .awaitingAnswer)
            var line = UnansweredNoticeLine()
            line.note(.init(noticeId: card.notice.id, maxY: -20))
            line.note(.init(noticeId: card.notice.id, maxY: 120))
            self.line = line
        }

        @Test("出さないこと")
        func hides() {
            #expect(!line.shows(for: card))
        }
    }

    @Suite("カードが画面の下にあり、遠くへ遡ってカードが描かれなくなったとき")
    struct ScrolledFarBelow {
        let card: NoticeCard
        let line: UnansweredNoticeLine

        init() throws {
            card = try UnansweredNoticeLineTests.card(form: .awaitingAnswer)
            var line = UnansweredNoticeLine()
            line.note(.init(noticeId: card.notice.id, maxY: 900))
            line.note(nil)
            self.line = line
        }

        @Test("出さないこと")
        func hides() {
            #expect(!line.shows(for: card))
        }
    }

    @Suite("上へ流れたあとに、知らせに答えたとき")
    struct AnsweredAfterScrolledAbove {
        let card: NoticeCard
        let line: UnansweredNoticeLine

        init() throws {
            let awaiting = try UnansweredNoticeLineTests.card(form: .awaitingAnswer)
            var line = UnansweredNoticeLine()
            line.note(.init(noticeId: awaiting.notice.id, maxY: -20))
            line.note(nil)
            self.line = line
            card = try UnansweredNoticeLineTests.card(form: .answered)
        }

        @Test("出さないこと")
        func hides() {
            #expect(!line.shows(for: card))
        }
    }
}
