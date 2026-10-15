import Foundation
import NuToriCore
import Testing

@Suite("答えていない知らせの1行")
struct UnansweredNoticeLineVisibilityTests {
    /// 東京の 2026-09-22 8:15 に出た、今日の答えていない体重の知らせの1行と、並べている日
    struct Fixture {
        let line: UnansweredNoticeLine
        let listedDays: ArraySlice<Timeline.Day>

        init() throws {
            let today = CalendarDay(year: 2026, month: 9, day: 22)
            let timeline = Timeline(
                input: Timeline.Input(
                    weightRecords: [], rejectedLines: [], meals: [],
                    notices: [try .missedWeightRecord(issuedAt: "2026-09-22T08:15:00+09:00")],
                    undelivered: .none, conversation: .none, goals: [], dailyGuides: []),
                firstDay: today, today: today)
            line = try #require(timeline.unansweredNoticeLines.first)
            listedDays = timeline.days[...]
        }
    }

    @Suite("今日の答えていない知らせのカードが、画面の上へ流れたとき")
    struct ScrolledAbove {
        let fixture: Fixture
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            fixture = try Fixture()
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: fixture.line.notice.id, maxY: -20))
            self.visibility = visibility
        }

        @Test("出すこと")
        func shows() {
            #expect(visibility.shows(fixture.line, listedDays: fixture.listedDays))
        }
    }

    @Suite("上へ流れたあと、遠くまで送ってカードが描かれなくなったとき")
    struct ScrolledFarAbove {
        let fixture: Fixture
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            fixture = try Fixture()
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: fixture.line.notice.id, maxY: -20))
            visibility.note(nil)
            self.visibility = visibility
        }

        @Test("出したままにすること")
        func keepsShowing() {
            #expect(visibility.shows(fixture.line, listedDays: fixture.listedDays))
        }
    }

    @Suite("カードが画面に見えているとき")
    struct Visible {
        let fixture: Fixture
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            fixture = try Fixture()
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: fixture.line.notice.id, maxY: -20))
            visibility.note(.init(noticeId: fixture.line.notice.id, maxY: 120))
            self.visibility = visibility
        }

        @Test("出さないこと")
        func hides() {
            #expect(!visibility.shows(fixture.line, listedDays: fixture.listedDays))
        }
    }

    @Suite("カードが画面の下にあり、遠くへ遡ってカードが描かれなくなったとき")
    struct ScrolledFarBelow {
        let fixture: Fixture
        let visibility: UnansweredNoticeLineVisibility

        init() throws {
            fixture = try Fixture()
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: fixture.line.notice.id, maxY: 900))
            visibility.note(nil)
            self.visibility = visibility
        }

        @Test("出さないこと")
        func hides() {
            #expect(!visibility.shows(fixture.line, listedDays: fixture.listedDays))
        }
    }
}
