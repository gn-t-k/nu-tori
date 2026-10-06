import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    @Suite("体重の知らせ")
    struct PlacingNotices {
        static let today = CalendarDay(year: 2026, month: 9, day: 24)

        @Suite("今日の答えていない知らせがあるとき")
        struct UnansweredToday {
            let morning: WeightRecord
            let notice: Notice
            let meal: MealCard
            let timeline: Timeline

            init() throws {
                morning = try .imported(72.4, at: "2026-09-23T07:12:00+09:00", in: "Asia/Tokyo")
                notice = try .missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")
                meal = MealCard(
                    meal: try .fixture(
                        eatenAt: "2026-09-24T07:40:00+09:00", sentAt: "2026-09-24T07:40:00+09:00"),
                    status: .estimated, recordedOnThisDevice: true)
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [morning], rejectedLines: [], meals: [meal],
                        notices: [notice]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: PlacingNotices.today
                )
            }

            @Test("出した時刻の位置に、答えていない形で置くこと")
            func placesAwaitingAnswerAtIssuedTime() {
                #expect(
                    timeline.days.last?.items == [
                        .meal(meal),
                        .notice(NoticeCard(notice: notice, form: .awaitingAnswer)),
                    ])
            }

            @Test("答えていない知らせの1行で示す知らせになること")
            func showsUnansweredLine() {
                #expect(
                    timeline.noticeAwaitingAnswer
                        == NoticeCard(notice: notice, form: .awaitingAnswer))
            }

            @Test("1行目に出す時刻を、出したときのタイムゾーンの時計の時刻にすること")
            func clockTimeInIssuedTimeZone() throws {
                let card = try #require(
                    timeline.days.last?.items.compactMap { item -> NoticeCard? in
                        if case .notice(let card) = item { card } else { nil }
                    }.first)
                #expect(card.clockTime == ClockTime(hour: 8, minute: 15))
            }
        }

        @Suite("今日の知らせに答えたとき")
        struct AnsweredToday {
            let notice: Notice
            let timeline: Timeline

            init() throws {
                notice = try Notice.missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")
                    .responded(
                        Notice.Response(
                            respondedAt: try Date("2026-09-24T09:00:00+09:00", strategy: .iso8601),
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))))
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [notice]),
                    firstDay: PlacingNotices.today,
                    today: PlacingNotices.today
                )
            }

            @Test("並べないこと")
            func doesNotPlaceAnswered() {
                #expect(timeline.days.last?.items == [])
            }

            @Test("記録忘れの通知から、いちばん新しい日の下に着くこと")
            func landsOnEndFromReminder() {
                #expect(
                    timeline.landing(for: .notice(id: notice.id)) == .end(PlacingNotices.today))
            }

            @Test("答えていない知らせの1行を出さないこと")
            func hidesUnansweredLine() {
                #expect(timeline.noticeAwaitingAnswer == nil)
            }
        }

        @Suite("前の日の答えていない知らせがあるとき")
        struct UnansweredPastDay {
            let notice: Notice
            let timeline: Timeline

            init() throws {
                notice = try .missedWeightRecord(issuedAt: "2026-09-23T08:15:00+09:00")
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [notice]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: PlacingNotices.today
                )
            }

            @Test("その日に、前の日の形で置くこと")
            func placesPastDayForm() {
                #expect(
                    timeline.days.map(\.items) == [
                        [.notice(NoticeCard(notice: notice, form: .unansweredPastDay))], [],
                    ])
            }

            @Test("答えていない知らせの1行を出さないこと")
            func hidesUnansweredLine() {
                #expect(timeline.noticeAwaitingAnswer == nil)
            }
        }
    }
}

extension TimelineTests {
    @Suite("記録忘れの通知から着く先")
    struct ReminderLandings {
        static let today = CalendarDay(year: 2026, month: 9, day: 24)

        @Suite("その知らせが並んでいるとき")
        struct NoticeListed {
            let notice: Notice
            let timeline: Timeline

            init() throws {
                notice = try .missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: [notice]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: ReminderLandings.today)
            }

            @Test("そのカードに着くこと")
            func landsOnNoticeCard() {
                #expect(
                    timeline.landing(for: .notice(id: notice.id))
                        == .item(
                            Timeline.Item.notice(NoticeCard(notice: notice, form: .awaitingAnswer))
                                .id))
            }
        }

        @Suite("知らせが無いと決まって開いたとき")
        struct TimelineEnd {
            let timeline: Timeline

            init() throws {
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [],
                        notices: [try .missedWeightRecord(issuedAt: "2026-09-24T08:15:00+09:00")]),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: ReminderLandings.today)
            }

            @Test("並んでいる知らせがあっても、いちばん新しい日の下に着くこと")
            func landsOnEnd() {
                #expect(timeline.landing(for: .timelineEnd) == .end(ReminderLandings.today))
            }
        }

        @Suite("その知らせが並んでいないとき")
        struct NoticeNotListed {
            let noticeId: UUID
            let timeline: Timeline

            init() {
                noticeId = UUID()
                timeline = Timeline(
                    input: Timeline.Input(
                        weightRecords: [], rejectedLines: [], meals: [], notices: []),
                    firstDay: CalendarDay(year: 2026, month: 9, day: 23),
                    today: ReminderLandings.today)
            }

            @Test("いちばん新しい日の下に着くこと")
            func landsOnEnd() {
                #expect(
                    timeline.landing(for: .notice(id: noticeId)) == .end(ReminderLandings.today))
            }
        }
    }
}

extension Notice {
    /// issuedAt は ISO 8601 の時刻。東京で出した、その日の体重の知らせ
    fileprivate static func missedWeightRecord(issuedAt: String) throws -> Notice {
        let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let issued = try Date(issuedAt, strategy: .iso8601)
        let day = CalendarDay(containing: issued, in: timeZone)
        return Notice(
            id: Notice.id(kind: .missedWeightRecord, targetDay: day),
            kind: .missedWeightRecord,
            issuedAt: issued,
            timeZone: timeZone,
            targetDay: day,
            response: nil
        )
    }
}
