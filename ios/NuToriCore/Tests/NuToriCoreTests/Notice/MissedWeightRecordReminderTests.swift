import Foundation
import NuToriCore
import Testing

@Suite("記録忘れの通知の予約の計画")
struct MissedWeightRecordReminderTests {
    @Suite("いつもの時刻が7:15で、今日の通知の時刻の前のとき")
    struct BeforeTodaysTime {
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                weightRecords: []
            )
        }

        @Test("今日から6日先までの7日分、1日1つ予約すること")
        func oneReminderPerDayForAWeek() {
            #expect(
                reminders.map(\.day) == [
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
            #expect(reminders.allSatisfy { $0.clockTime == ClockTime(hour: 8, minute: 15) })
            #expect(
                try #require(reminders.first).fireDate
                    == Date("2026-09-22T08:15:00+09:00", strategy: .iso8601))
        }

        @Test("ID を、その日の体重の知らせの ID にすること")
        func usesTheNoticeIdOfTheDay() throws {
            #expect(
                try #require(reminders.first).id
                    == UUID(uuidString: "B57A32FD-45B8-5188-9AFC-5FB5D28C26C9"))
        }
    }

    @Suite("今日の通知の時刻が過ぎたとき")
    struct AfterTodaysTime {
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T08:15:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                weightRecords: []
            )
        }

        @Test("今日を外し、明日から6日先までを予約すること")
        func skipsToday() {
            #expect(
                reminders.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 23),
                    CalendarDay(year: 2026, month: 9, day: 24),
                    CalendarDay(year: 2026, month: 9, day: 25),
                    CalendarDay(year: 2026, month: 9, day: 26),
                    CalendarDay(year: 2026, month: 9, day: 27),
                    CalendarDay(year: 2026, month: 9, day: 28),
                ])
        }
    }

    @Suite("今日と先の日付に体重記録があるとき")
    struct WithRecordsOnTodayAndLater {
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                weightRecords: [
                    try .manual(60.0, at: "2026-09-22T06:50:00+09:00", in: "Asia/Tokyo"),
                    try .imported(60.2, at: "2026-09-24T23:50:00+09:00", in: "Asia/Tokyo"),
                ]
            )
        }

        @Test("体重記録のある日付の分を外すこと")
        func skipsRecordedDays() {
            #expect(
                reminders.map(\.day) == [
                    CalendarDay(year: 2026, month: 9, day: 23),
                    CalendarDay(year: 2026, month: 9, day: 25),
                    CalendarDay(year: 2026, month: 9, day: 26),
                    CalendarDay(year: 2026, month: 9, day: 27),
                    CalendarDay(year: 2026, month: 9, day: 28),
                ])
        }
    }

    @Suite("東京で記録してからホノルルへ移り、日付が戻ったとき")
    struct AfterMovingWest {
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            // ホノルルでは 9/21 5:30
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 435),
                now: try Date("2026-09-22T00:30:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Pacific/Honolulu")),
                weightRecords: [
                    try .manual(60.0, at: "2026-09-22T00:10:00+09:00", in: "Asia/Tokyo")
                ]
            )
        }

        @Test("ホノルルの時計の8:15で予約すること")
        func firesOnTheLocalClock() throws {
            #expect(
                try #require(reminders.first).fireDate
                    == Date("2026-09-21T08:15:00-10:00", strategy: .iso8601))
        }

        @Test("東京で記録した日付の分を、移った先でも外すこと")
        func skipsTheDayRecordedBeforeMoving() {
            #expect(
                reminders.map(\.day) == [
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
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: UsualWeighingTime(id: UUID(), minuteOfDay: 1380),
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                weightRecords: []
            )
        }

        @Test("翌日に回さず、その日の23:59に予約すること")
        func firesAt2359OfTheSameDay() throws {
            #expect(
                try #require(reminders.first).fireDate
                    == Date("2026-09-22T23:59:00+09:00", strategy: .iso8601))
        }
    }

    @Suite("いつもの時刻がまだ届いていないとき")
    struct WithoutUsualTime {
        let reminders: [MissedWeightRecordReminder]

        init() throws {
            reminders = MissedWeightRecordReminder.plan(
                usualWeighingTime: nil,
                now: try Date("2026-09-22T07:00:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                weightRecords: []
            )
        }

        @Test("朝7時の1時間後の8:00に予約すること")
        func firesAtEight() throws {
            #expect(
                try #require(reminders.first).fireDate
                    == Date("2026-09-22T08:00:00+09:00", strategy: .iso8601))
        }
    }
}
