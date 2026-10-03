import Foundation
import NuToriCore
import Testing

@Suite("答えていない知らせの1行")
struct UnansweredNoticeLineVisibilityTests {
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
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            card = try UnansweredNoticeLineVisibilityTests.card(form: .awaitingAnswer)
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: card.notice.id, maxY: -20))
            self.visibility = visibility
        }

        @Test("出すこと")
        func shows() {
            #expect(visibility.shows(for: card))
        }
    }

    @Suite("上へ流れたあと、遠くまで送ってカードが描かれなくなったとき")
    struct ScrolledFarAbove {
        let card: NoticeCard
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            card = try UnansweredNoticeLineVisibilityTests.card(form: .awaitingAnswer)
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: card.notice.id, maxY: -20))
            visibility.note(nil)
            self.visibility = visibility
        }

        @Test("出したままにすること")
        func keepsShowing() {
            #expect(visibility.shows(for: card))
        }
    }

    @Suite("カードが画面に見えているとき")
    struct Visible {
        let card: NoticeCard
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            card = try UnansweredNoticeLineVisibilityTests.card(form: .awaitingAnswer)
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: card.notice.id, maxY: -20))
            visibility.note(.init(noticeId: card.notice.id, maxY: 120))
            self.visibility = visibility
        }

        @Test("出さないこと")
        func hides() {
            #expect(!visibility.shows(for: card))
        }
    }

    @Suite("カードが画面の下にあり、遠くへ遡ってカードが描かれなくなったとき")
    struct ScrolledFarBelow {
        let card: NoticeCard
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            card = try UnansweredNoticeLineVisibilityTests.card(form: .awaitingAnswer)
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: card.notice.id, maxY: 900))
            visibility.note(nil)
            self.visibility = visibility
        }

        @Test("出さないこと")
        func hides() {
            #expect(!visibility.shows(for: card))
        }
    }

    @Suite("上へ流れたあとに、知らせに答えたとき")
    struct AnsweredAfterScrolledAbove {
        let card: NoticeCard
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            let awaiting = try UnansweredNoticeLineVisibilityTests.card(form: .awaitingAnswer)
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: awaiting.notice.id, maxY: -20))
            visibility.note(nil)
            self.visibility = visibility
            card = try UnansweredNoticeLineVisibilityTests.card(form: .answered)
        }

        @Test("出さないこと")
        func hides() {
            #expect(!visibility.shows(for: card))
        }
    }
}
