public import Foundation

/// 予約する記録忘れの通知の1つ。通知の層（`UNUserNotificationCenter`）は、これを今の土地の時計の時刻で予約する
public struct MissedWeightRecordReminder: Hashable, Sendable {
    /// 予約の ID。その日の体重の知らせの ID と同じ値にし、押したときにどの日の分かを分かるようにする
    public let id: UUID
    public let day: CalendarDay
    /// 今のタイムゾーンでの時計の時刻
    public let clockTime: ClockTime
    public let fireDate: Date

    /// 今日から6日先までの7日分、1日1つ。今日の時刻が過ぎた分と、その日付の体重記録がある日の分は外す。
    /// 体重記録の日付は記録したときのタイムゾーンで数えるので、西へ移った日は、移る前の土地の同じ日付の記録で外れる（受け入れる限界）
    public static func plan(
        usualWeighingTime: UsualWeighingTime?,
        now: Date,
        timeZone: TimeZone,
        weightRecords: [WeightRecord]
    ) -> [MissedWeightRecordReminder] {
        let recordedDays = Set(weightRecords.map(\.day))
        let today = CalendarDay(containing: now, in: timeZone)
        return (0...6)
            .map { today.advanced(by: $0) }
            .filter { !recordedDays.contains($0) }
            .compactMap {
                MissedWeightRecordReminder(
                    day: $0, usualWeighingTime: usualWeighingTime, in: timeZone)
            }
            .filter { $0.fireDate > now }
    }

    /// その日の通知の時刻（今のタイムゾーン）。Calendar が時刻を出せなければ nil
    init?(day: CalendarDay, usualWeighingTime: UsualWeighingTime?, in timeZone: TimeZone) {
        let clockTime = Self.clockTime(after: usualWeighingTime)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // 夏時間で飛んだ時計の時刻は、Calendar がそのあとの時刻に寄せる
        guard
            let fireDate = calendar.date(
                from: DateComponents(
                    year: day.year, month: day.month, day: day.day,
                    hour: clockTime.hour, minute: clockTime.minute))
        else {
            return nil
        }
        self.init(
            id: Notice.id(kind: .missedWeightRecord, targetDay: day),
            day: day,
            clockTime: clockTime,
            fireDate: fireDate
        )
    }

    private init(id: UUID, day: CalendarDay, clockTime: ClockTime, fireDate: Date) {
        self.id = id
        self.day = day
        self.clockTime = clockTime
        self.fireDate = fireDate
    }

    /// いつもの時刻（届いていなければ朝7時）の1時間後。翌日の 0:00 以降になるときは、その日の 23:59
    private static func clockTime(after usualWeighingTime: UsualWeighingTime?) -> ClockTime {
        let firstUseMinuteOfDay = 7 * 60
        let minuteOfDay = (usualWeighingTime?.minuteOfDay ?? firstUseMinuteOfDay) + 60
        guard minuteOfDay < 24 * 60 else {
            return ClockTime(hour: 23, minute: 59)
        }
        return ClockTime(hour: minuteOfDay / 60, minute: minuteOfDay % 60)
    }
}
