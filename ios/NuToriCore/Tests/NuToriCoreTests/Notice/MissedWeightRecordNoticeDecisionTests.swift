import Foundation
import NuToriCore
import Testing

@Suite("体重の知らせを出す・答える判断")
struct MissedWeightRecordNoticeDecisionTests {
    @Suite("出す判断")
    struct Issuing {
        @Suite("今日の通知の時刻を過ぎ、今日の体重記録も知らせも無いとき")
        struct AfterTimeWithoutRecordOrNotice {
            let notice: Notice?

            init() throws {
                notice = MissedWeightRecordNoticeDecision.noticeToIssue(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: [
                        try .manual(60.0, at: "2026-09-21T07:00:00+09:00", in: "Asia/Tokyo")
                    ],
                    notices: []
                )
            }

            @Test("今日の答えていない知らせを、通知の時刻に出した形で作ること")
            func issuesTodaysNoticeAtTheReminderTime() throws {
                #expect(
                    notice
                        == Notice(
                            id: try #require(
                                UUID(uuidString: "B57A32FD-45B8-5188-9AFC-5FB5D28C26C9")),
                            kind: .missedWeightRecord,
                            issuedAt: try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601),
                            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                            targetDay: CalendarDay(year: 2026, month: 9, day: 22),
                            response: nil
                        ))
            }
        }

        @Suite("いつもの時刻がまだ届いておらず、今が8:00ちょうどのとき")
        struct AtFirstUseTime {
            let notice: Notice?

            init() throws {
                notice = MissedWeightRecordNoticeDecision.noticeToIssue(
                    usualWeighingTime: nil,
                    now: try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: [],
                    notices: []
                )
            }

            @Test("8:00に出した今日の知らせを作ること")
            func issuesAtEight() throws {
                #expect(
                    try #require(notice).issuedAt
                        == Date("2026-09-22T08:00:00+09:00", strategy: .iso8601))
            }
        }

        @Suite("今日の通知の時刻の前のとき")
        struct BeforeTime {
            let notice: Notice?

            init() throws {
                // 昨日の分も、記録も知らせも無い
                notice = MissedWeightRecordNoticeDecision.noticeToIssue(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T08:14:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: [],
                    notices: []
                )
            }

            @Test("今日の分も、過ぎた日の分も出さないこと")
            func issuesNothing() {
                #expect(notice == nil)
            }
        }

        @Suite("今日の日付の体重記録があるとき")
        struct WithTodaysRecord {
            let notice: Notice?

            init() throws {
                notice = MissedWeightRecordNoticeDecision.noticeToIssue(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: [
                        try .imported(60.0, at: "2026-09-22T09:10:00+09:00", in: "Asia/Tokyo")
                    ],
                    notices: []
                )
            }

            @Test("出さないこと")
            func issuesNothing() {
                #expect(notice == nil)
            }
        }

        @Suite("今日の知らせがすでにあるとき")
        struct WithTodaysNotice {
            let notice: Notice?

            init() throws {
                let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
                let today = CalendarDay(year: 2026, month: 9, day: 22)
                notice = MissedWeightRecordNoticeDecision.noticeToIssue(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: tokyo,
                    weightRecords: [],
                    notices: [
                        Notice(
                            id: Notice.id(kind: .missedWeightRecord, targetDay: today),
                            kind: .missedWeightRecord,
                            issuedAt: try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601),
                            timeZone: tokyo,
                            targetDay: today,
                            response: Notice.Response(
                                respondedAt: try Date(
                                    "2026-09-22T08:40:00+09:00", strategy: .iso8601),
                                timeZone: tokyo)
                        )
                    ]
                )
            }

            @Test("出さないこと")
            func issuesNothing() {
                #expect(notice == nil)
            }
        }
    }

    @Suite("答える判断")
    struct Responding {
        let unansweredWithRecord: Notice
        let noticeIds: [UUID]

        init() throws {
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            func notice(on day: Int, respondedAt: String?) throws -> Notice {
                let targetDay = CalendarDay(year: 2026, month: 9, day: day)
                return Notice(
                    id: Notice.id(kind: .missedWeightRecord, targetDay: targetDay),
                    kind: .missedWeightRecord,
                    issuedAt: try Date(
                        "2026-09-\(day)T08:15:00+09:00", strategy: .iso8601),
                    timeZone: tokyo,
                    targetDay: targetDay,
                    response: try respondedAt.map {
                        Notice.Response(
                            respondedAt: try Date($0, strategy: .iso8601), timeZone: tokyo)
                    }
                )
            }
            unansweredWithRecord = try notice(on: 21, respondedAt: nil)
            noticeIds = MissedWeightRecordNoticeDecision.noticeIdsToRespond(
                notices: [
                    try notice(on: 20, respondedAt: "2026-09-20T09:00:00+09:00"),
                    unansweredWithRecord,
                    try notice(on: 22, respondedAt: nil),
                ],
                weightRecords: [
                    try .manual(60.0, at: "2026-09-20T09:00:00+09:00", in: "Asia/Tokyo"),
                    try .imported(60.1, at: "2026-09-21T23:30:00+09:00", in: "Asia/Tokyo"),
                ]
            )
        }

        @Test("答えていない知らせのうち、対象の日付の体重記録があるものにだけ答えること")
        func respondsToUnansweredNoticesWithRecord() {
            #expect(noticeIds == [unansweredWithRecord.id])
        }
    }

    /// いつもの時刻は 7:15 なので、通知の時刻は 8:15
    @Suite("開いているあいだに、次に出すかを決める時刻")
    struct NextNoticeTime {
        @Suite("今日の通知の時刻の前で、今日の体重記録が無いとき")
        struct BeforeTodaysTime {
            let nextTime: Date?

            init() throws {
                nextTime = MissedWeightRecordNoticeDecision.nextNoticeTime(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T08:14:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: []
                )
            }

            @Test("今日の通知の時刻であること")
            func isTodaysTime() throws {
                #expect(nextTime == (try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601)))
            }
        }

        @Suite("今日の通知の時刻を過ぎたとき")
        struct AfterTodaysTime {
            let nextTime: Date?

            init() throws {
                nextTime = MissedWeightRecordNoticeDecision.nextNoticeTime(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: []
                )
            }

            @Test("開いたまま日付が変わったときのために、明日の通知の時刻であること")
            func isTomorrowsTime() throws {
                #expect(nextTime == (try Date("2026-09-23T08:15:00+09:00", strategy: .iso8601)))
            }
        }

        @Suite("今日の通知の時刻の前で、今日の体重記録があるとき")
        struct RecordedToday {
            let nextTime: Date?

            init() throws {
                nextTime = MissedWeightRecordNoticeDecision.nextNoticeTime(
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                    weightRecords: [
                        try .manual(60.0, at: "2026-09-22T07:10:00+09:00", in: "Asia/Tokyo")
                    ]
                )
            }

            @Test("明日の通知の時刻であること")
            func isTomorrowsTime() throws {
                #expect(nextTime == (try Date("2026-09-23T08:15:00+09:00", strategy: .iso8601)))
            }
        }
    }
}
