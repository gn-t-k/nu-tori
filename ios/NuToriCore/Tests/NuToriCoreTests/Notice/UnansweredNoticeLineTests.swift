import Foundation
import NuToriCore
import Testing

/// 東京の 2026-09-24。体重の知らせは 8:15 に出る
@Suite("帯の下に示す、答えていない知らせ")
struct UnansweredNoticeLineTests {
    static let today = CalendarDay(year: 2026, month: 9, day: 24)

    /// 東京で出した、答えていない目標を立てる知らせ。issuedAt は ISO 8601 の時刻
    static func goalSetup(issuedAt: String) throws -> Notice {
        Notice(
            id: Notice.id(of: .goalSetup), kind: .goalSetup,
            issuedAt: try Date(issuedAt, strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), response: nil)
    }

    static func timeline(notices: [Notice]) -> Timeline {
        Timeline(
            input: Timeline.Input(
                goalRecords: GoalRecords(
                    goals: [], dailyGuides: [], expenditureEstimates: [], weeklyReviews: [],
                    weightTrend: nil, weightRecords: []), rejectedLines: [], meals: [],
                notices: notices, undelivered: .none, conversation: .none),
            firstDay: CalendarDay(year: 2026, month: 9, day: 20), today: today)
    }

    @Suite("答えていない目標を立てる知らせがあるとき")
    struct UnansweredGoalSetup {
        let notice: Notice
        let timeline: Timeline

        init() throws {
            notice = try UnansweredNoticeLineTests.goalSetup(issuedAt: "2026-09-22T19:00:00+09:00")
            timeline = UnansweredNoticeLineTests.timeline(notices: [notice])
        }

        @Test("「目標を立てる」の1行が並ぶこと")
        func listsGoalSetupLine() {
            #expect(timeline.unansweredNoticeLines == [.goalSetup(notice)])
        }

        @Test("体重の知らせのカードとしては並べないこと")
        func doesNotPlaceAsWeightNotice() {
            #expect(timeline.days.flatMap(\.items) == [.goalSetupNotice(notice)])
            #expect(timeline.noticeAwaitingAnswer == nil)
        }

        @Suite("カードが画面の上へ流れたとき")
        struct CardAbove {
            let line: UnansweredNoticeLine
            let days: [Timeline.Day]
            let visibility: UnansweredNoticeLineVisibility

            init() throws {
                let notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-22T19:00:00+09:00")
                line = .goalSetup(notice)
                days = UnansweredNoticeLineTests.timeline(notices: [notice]).days
                var visibility = UnansweredNoticeLineVisibility()
                visibility.note(.init(noticeId: notice.id, maxY: -20))
                self.visibility = visibility
            }

            @Test("1行を出すこと")
            func shows() {
                #expect(visibility.shows(line, listedDays: days[...]))
            }

            @Test("カードが見えるところへ戻ると、1行を出さないこと")
            func hidesWhenCardReturns() {
                var visibility = visibility
                visibility.note(.init(noticeId: line.notice.id, maxY: 120))

                #expect(!visibility.shows(line, listedDays: days[...]))
            }
        }

        @Test("カードが見えているあいだは、1行を出さないこと")
        func hidesWhileCardVisible() {
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: notice.id, maxY: 300))

            #expect(!visibility.shows(.goalSetup(notice), listedDays: timeline.days[...]))
        }

        @Suite("開き直して、カードを置いた日をまだ並べていないとき")
        struct CardDayNotListed {
            let notice: Notice
            let listedDays: ArraySlice<Timeline.Day>

            init() throws {
                notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-22T19:00:00+09:00")
                listedDays = UnansweredNoticeLineTests.timeline(notices: [notice]).days.suffix(2)
                try #require(
                    listedDays.map(\.day) == [
                        CalendarDay(year: 2026, month: 9, day: 23), UnansweredNoticeLineTests.today,
                    ])
            }

            @Test("カードは並べた日より上にあるので、位置が届いていなくても1行を出すこと")
            func shows() {
                #expect(
                    UnansweredNoticeLineVisibility().shows(
                        .goalSetup(notice), listedDays: listedDays))
            }
        }

        @Suite("カードを置いた日を並べていて、位置がまだ届いていないとき")
        struct CardDayListedWithoutPosition {
            let notice: Notice
            let listedDays: ArraySlice<Timeline.Day>

            init() throws {
                notice = try UnansweredNoticeLineTests.goalSetup(
                    issuedAt: "2026-09-22T19:00:00+09:00")
                listedDays = UnansweredNoticeLineTests.timeline(notices: [notice]).days[...]
            }

            @Test("1行を出さないこと")
            func hides() {
                #expect(
                    !UnansweredNoticeLineVisibility().shows(
                        .goalSetup(notice), listedDays: listedDays))
            }
        }
    }

    @Suite("目標が決まって、目標を立てる知らせが答えた形になったとき")
    struct AnsweredGoalSetup {
        let timeline: Timeline

        init() throws {
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            let notice = try UnansweredNoticeLineTests.goalSetup(
                issuedAt: "2026-09-22T19:00:00+09:00"
            ).responded(
                Notice.Response(
                    respondedAt: try Date("2026-09-22T19:05:00+09:00", strategy: .iso8601),
                    timeZone: tokyo))
            timeline = UnansweredNoticeLineTests.timeline(notices: [notice])
        }

        @Test("1行が並ばないこと")
        func listsNoLine() {
            #expect(timeline.unansweredNoticeLines.isEmpty)
        }
    }

    @Suite("今日の答えていない体重の知らせと、あとから出た目標を立てる知らせがあるとき")
    struct WeightAndGoalSetup {
        let weightNotice: Notice
        let goalSetup: Notice
        let timeline: Timeline

        init() throws {
            weightNotice = try .missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")
            goalSetup = try UnansweredNoticeLineTests.goalSetup(
                issuedAt: "2026-09-24T12:00:00+09:00")
            timeline = UnansweredNoticeLineTests.timeline(notices: [goalSetup, weightNotice])
        }

        @Test("出した時刻の古い順に、体重の知らせ、目標を立てる知らせの1行が並ぶこと")
        func listsBothOldestFirst() {
            #expect(
                timeline.unansweredNoticeLines == [
                    .missedWeightRecord(NoticeCard(notice: weightNotice, form: .awaitingAnswer)),
                    .goalSetup(goalSetup),
                ])
        }

        @Test("上へ流れたカードの知らせだけ、1行を出すこと")
        func showsOnlyLinesWhoseCardIsAbove() {
            var visibility = UnansweredNoticeLineVisibility()
            visibility.note(.init(noticeId: weightNotice.id, maxY: -40))
            visibility.note(.init(noticeId: goalSetup.id, maxY: 200))

            #expect(
                timeline.unansweredNoticeLines.map {
                    visibility.shows($0, listedDays: timeline.days[...])
                } == [true, false])
        }
    }

    @Suite("前の日の答えていない体重の知らせだけがあるとき")
    struct PastDayWeightNotice {
        let timeline: Timeline

        init() throws {
            timeline = UnansweredNoticeLineTests.timeline(notices: [
                try .missedWeightRecord(issuedAt: "2026-09-23T08:15:00+09:00")
            ])
        }

        @Test("1行が並ばないこと")
        func listsNoLine() {
            #expect(timeline.unansweredNoticeLines.isEmpty)
        }
    }
}
