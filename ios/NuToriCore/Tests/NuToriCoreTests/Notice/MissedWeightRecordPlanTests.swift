import Foundation
import NuToriCore
import Testing

/// 東京の 2026年9月。いつもの時刻が 7:15 なら、通知の時刻は 8:15
@Suite("記録忘れの計画")
struct MissedWeightRecordPlanTests {
    /// 2026年9月のその日の、記録忘れの知らせと通知の ID
    static func id(_ day: Int) -> UUID {
        Notice.id(
            kind: .missedWeightRecord, targetDay: CalendarDay(year: 2026, month: 9, day: day))
    }

    /// 2026年9月のその日の8:15に出した、記録忘れの知らせ
    static func notice(on day: Int, respondedAt: String?) throws -> Notice {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        return Notice(
            id: id(day),
            kind: .missedWeightRecord,
            issuedAt: try Date("2026-09-\(day)T08:15:00+09:00", strategy: .iso8601),
            timeZone: tokyo,
            targetDay: CalendarDay(year: 2026, month: 9, day: day),
            response: try respondedAt.map {
                Notice.Response(respondedAt: try Date($0, strategy: .iso8601), timeZone: tokyo)
            }
        )
    }

    @Suite("今日の通知の時刻の前で、体重記録も知らせも無いとき")
    struct BeforeTodaysTime {
        let plan: MissedWeightRecordPlan

        init() throws {
            // 昨日の分も、記録も知らせも無い
            plan = MissedWeightRecordPlan(
                weightRecords: [],
                notices: [],
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("今日の分も、過ぎた日の分も知らせを出さないこと")
        func issuesNothing() {
            #expect(plan.noticeToIssue == nil)
        }

        @Test("今日から6日先までの7日分、1日1つ予約すること")
        func oneReminderPerDayForAWeek() {
            #expect(
                plan.reminders.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 22),
                    CalendarDay(year: 2026, month: 9, day: 23),
                    CalendarDay(year: 2026, month: 9, day: 24),
                    CalendarDay(year: 2026, month: 9, day: 25),
                    CalendarDay(year: 2026, month: 9, day: 26),
                    CalendarDay(year: 2026, month: 9, day: 27),
                    CalendarDay(year: 2026, month: 9, day: 28),
                ])
        }

        @Test("どの日も、いつもの時刻の1時間後の8:15に予約すること")
        func firesAnHourAfterTheUsualTime() throws {
            #expect(plan.reminders.allSatisfy { $0.clockTime == ClockTime(hour: 8, minute: 15) })
            #expect(
                try #require(plan.reminders.first).fireDate
                    == Date("2026-09-22T08:15:00+09:00", strategy: .iso8601))
        }

        @Test("ID を、その日の体重の知らせの ID にすること")
        func usesTheNoticeIdOfTheDay() throws {
            #expect(
                try #require(plan.reminders.first).id
                    == UUID(uuidString: "B57A32FD-45B8-5188-9AFC-5FB5D28C26C9"))
        }

        @Test("次に知らせを出すかを決める時刻が、今日の通知の時刻であること")
        func nextNoticeTimeIsToday() throws {
            #expect(
                plan.nextNoticeTime == (try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601)))
        }
    }

    @Suite("今日の通知の時刻を過ぎ、今日の体重記録も知らせも無く、ほかの日の記録と知らせがあるとき")
    struct AfterTodaysTimeWithOtherDays {
        let plan: MissedWeightRecordPlan
        let unansweredWithRecord: Notice
        let delivered: [UUID]

        init() throws {
            delivered = [19, 21, 22, 24].map(MissedWeightRecordPlanTests.id)
            unansweredWithRecord = try MissedWeightRecordPlanTests.notice(
                on: 21, respondedAt: nil)
            plan = MissedWeightRecordPlan(
                weightRecords: [
                    try .manual(60.0, at: "2026-09-20T09:00:00+09:00", in: "Asia/Tokyo"),
                    try .imported(60.1, at: "2026-09-21T23:30:00+09:00", in: "Asia/Tokyo"),
                    try .imported(60.2, at: "2026-09-24T23:50:00+09:00", in: "Asia/Tokyo"),
                ],
                notices: [
                    try MissedWeightRecordPlanTests.notice(
                        on: 19, respondedAt: nil),
                    try MissedWeightRecordPlanTests.notice(
                        on: 20, respondedAt: "2026-09-20T09:00:00+09:00"),
                    unansweredWithRecord,
                ],
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("答えていない知らせのうち、対象の日付の体重記録があるものにだけ答えること")
        func respondsToUnansweredNoticesWithRecord() {
            #expect(plan.noticesToRespond == [unansweredWithRecord])
        }

        @Test("今日の答えていない知らせを、通知の時刻に出した形で作ること")
        func issuesTodaysNoticeAtTheReminderTime() throws {
            #expect(
                plan.noticeToIssue
                    == Notice(
                        id: try #require(UUID(uuidString: "B57A32FD-45B8-5188-9AFC-5FB5D28C26C9")),
                        kind: .missedWeightRecord,
                        issuedAt: try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601),
                        timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                        targetDay: CalendarDay(year: 2026, month: 9, day: 22),
                        response: nil
                    ))
        }

        @Test("知らせを出した今日と、体重記録のある日付の分を外して予約すること")
        func skipsTodayAndRecordedDays() {
            #expect(
                plan.reminders.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 23),
                    CalendarDay(year: 2026, month: 9, day: 25),
                    CalendarDay(year: 2026, month: 9, day: 26),
                    CalendarDay(year: 2026, month: 9, day: 27),
                    CalendarDay(year: 2026, month: 9, day: 28),
                ])
        }

        @Test("通知センターに残った通知のうち、答える知らせと同じ体重記録のある日の分だけを外すこと")
        func removesDeliveredOnRecordedDays() {
            #expect(
                plan.deliveredIdsToRemove(from: delivered)
                    == [MissedWeightRecordPlanTests.id(21), MissedWeightRecordPlanTests.id(24)])
        }

        @Test("開いたまま日付が変わったときのために、次に決める時刻が最初の予約の明日の通知の時刻であること")
        func nextNoticeTimeIsTomorrow() throws {
            #expect(
                plan.nextNoticeTime == (try Date("2026-09-23T08:15:00+09:00", strategy: .iso8601)))
        }
    }

    @Suite("いつもの時刻がまだ届いておらず、今が8:00ちょうどのとき")
    struct AtFirstUseTime {
        let plan: MissedWeightRecordPlan

        init() throws {
            plan = MissedWeightRecordPlan(
                weightRecords: [],
                notices: [],
                usualWeighingTime: nil,
                now: try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("朝7時の1時間後の8:00に出した、今日の知らせを作ること")
        func issuesAtEight() throws {
            #expect(
                try #require(plan.noticeToIssue).issuedAt
                    == Date("2026-09-22T08:00:00+09:00", strategy: .iso8601))
        }

        @Test("知らせを出す今日は予約せず、明日の8:00から予約すること")
        func remindsFromTomorrowAtEight() throws {
            #expect(plan.reminders.first?.day == CalendarDay(year: 2026, month: 9, day: 23))
            #expect(
                plan.nextNoticeTime == (try Date("2026-09-23T08:00:00+09:00", strategy: .iso8601)))
        }
    }

    @Suite("今日の日付の体重記録があるとき")
    struct WithTodaysRecord {
        @Suite("今日の通知の時刻の前のとき")
        struct BeforeTodaysTime {
            let plan: MissedWeightRecordPlan
            let delivered: [UUID]

            init() throws {
                delivered = [MissedWeightRecordPlanTests.id(22)]
                plan = MissedWeightRecordPlan(
                    weightRecords: [
                        try .manual(60.0, at: "2026-09-22T07:10:00+09:00", in: "Asia/Tokyo")
                    ],
                    notices: [],
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T08:00:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("今日を予約せず、次に決める時刻が明日の通知の時刻であること")
            func remindsFromTomorrow() throws {
                #expect(plan.reminders.first?.day == CalendarDay(year: 2026, month: 9, day: 23))
                #expect(
                    plan.nextNoticeTime
                        == (try Date("2026-09-23T08:15:00+09:00", strategy: .iso8601)))
            }

            @Test("通知センターに残った今日の通知を外すこと")
            func removesTodaysDelivered() {
                #expect(
                    plan.deliveredIdsToRemove(from: delivered)
                        == [MissedWeightRecordPlanTests.id(22)])
            }
        }

        @Suite("今日の通知の時刻を過ぎたとき")
        struct AfterTodaysTime {
            let plan: MissedWeightRecordPlan

            init() throws {
                plan = MissedWeightRecordPlan(
                    weightRecords: [
                        try .imported(60.0, at: "2026-09-22T09:10:00+09:00", in: "Asia/Tokyo")
                    ],
                    notices: [],
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("知らせを出さないこと")
            func issuesNothing() {
                #expect(plan.noticeToIssue == nil)
            }
        }
    }

    @Suite("今日の通知の時刻を過ぎ、今日の知らせがすでにあるとき")
    struct WithTodaysNotice {
        @Suite("答えていないとき")
        struct Unanswered {
            let plan: MissedWeightRecordPlan

            init() throws {
                plan = MissedWeightRecordPlan(
                    weightRecords: [],
                    notices: [try MissedWeightRecordPlanTests.notice(on: 22, respondedAt: nil)],
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("同じ知らせをもう一度出さず、答えもしないこと")
            func neitherIssuesNorResponds() {
                #expect(plan.noticeToIssue == nil)
                #expect(plan.noticesToRespond.isEmpty)
            }
        }

        @Suite("もう答えたとき")
        struct Answered {
            let plan: MissedWeightRecordPlan

            init() throws {
                plan = MissedWeightRecordPlan(
                    weightRecords: [],
                    notices: [
                        try MissedWeightRecordPlanTests.notice(
                            on: 22, respondedAt: "2026-09-22T08:40:00+09:00")
                    ],
                    usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                    now: try Date("2026-09-22T09:30:00+09:00", strategy: .iso8601),
                    timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
                )
            }

            @Test("知らせを出さないこと")
            func issuesNothing() {
                #expect(plan.noticeToIssue == nil)
            }
        }
    }

    @Suite("東京で記録してからホノルルへ移り、日付が戻ったとき")
    struct AfterMovingWest {
        let plan: MissedWeightRecordPlan

        init() throws {
            // ホノルルでは 9/21 5:30
            plan = MissedWeightRecordPlan(
                weightRecords: [
                    try .manual(60.0, at: "2026-09-22T00:10:00+09:00", in: "Asia/Tokyo")
                ],
                notices: [],
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T00:30:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Pacific/Honolulu"))
            )
        }

        @Test("ホノルルの時計の8:15で予約すること")
        func firesOnTheLocalClock() throws {
            #expect(
                try #require(plan.reminders.first).fireDate
                    == Date("2026-09-21T08:15:00-10:00", strategy: .iso8601))
        }

        @Test("東京で記録した日付の分を、移った先でも外すこと")
        func skipsTheDayRecordedBeforeMoving() {
            #expect(
                plan.reminders.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 21),
                    CalendarDay(year: 2026, month: 9, day: 23),
                    CalendarDay(year: 2026, month: 9, day: 24),
                    CalendarDay(year: 2026, month: 9, day: 25),
                    CalendarDay(year: 2026, month: 9, day: 26),
                    CalendarDay(year: 2026, month: 9, day: 27),
                ])
        }
    }

    @Suite("いつもの時刻が23:00のとき")
    struct UsualTimeLateAtNight {
        let plan: MissedWeightRecordPlan

        init() throws {
            plan = MissedWeightRecordPlan(
                weightRecords: [],
                notices: [],
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 1380),
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo"))
            )
        }

        @Test("翌日に回さず、その日の23:59に予約すること")
        func firesAt2359OfTheSameDay() throws {
            #expect(
                try #require(plan.reminders.first).fireDate
                    == Date("2026-09-22T23:59:00+09:00", strategy: .iso8601))
        }
    }
}
