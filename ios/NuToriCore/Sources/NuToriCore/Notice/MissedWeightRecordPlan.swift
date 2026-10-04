public import Foundation

/// 記録忘れの計画。体重記録・知らせ・いつもの時刻・今・タイムゾーンから、答える知らせ、出す知らせ、予約する通知、
/// 通知センターから外す通知、次に知らせを出すかを決める時刻を一度に決める。
/// 「記録した日」と、日ごとの知らせ（と通知）の ID は、ここでだけ作る。
/// 体重記録の日付は記録したときのタイムゾーンで数えるので、西へ移った日は、移る前の土地の同じ日付の記録で記録した日になる（受け入れる限界）
public struct MissedWeightRecordPlan: Sendable {
    public init(
        weightRecords: [WeightRecord],
        notices: [Notice],
        usualWeighingTime: UsualWeighingTime?,
        now: Date,
        timeZone: TimeZone
    ) {
        let recordedDays = Set(weightRecords.map(\.day))
        let clockTime = Self.clockTime(after: usualWeighingTime)
        let today = CalendarDay(containing: now, in: timeZone)
        let week = (0...6).compactMap {
            Self.reminder(on: today.advanced(by: $0), at: clockTime, in: timeZone)
        }
        let unrecordedWeek = week.filter { !recordedDays.contains($0.day) }

        noticesToRespond = notices.filter {
            $0.response == nil && recordedDays.contains($0.targetDay)
        }
        // 過ぎた日の分は作らない（アプリを開かなかった日の知らせを、あとから出さない）
        if let todays = unrecordedWeek.first(where: { $0.day == today }),
            todays.fireDate <= now,
            !notices.contains(where: { $0.id == todays.id })
        {
            noticeToIssue = Notice(
                id: todays.id,
                kind: .missedWeightRecord,
                issuedAt: todays.fireDate,
                timeZone: timeZone,
                targetDay: today,
                response: nil
            )
        } else {
            noticeToIssue = nil
        }
        reminders = unrecordedWeek.filter { $0.fireDate > now }
        recordedDayIds = Set(recordedDays.map(Self.id(on:)))
    }

    /// 答えていない知らせのうち、対象の日付の体重記録があるもの
    public let noticesToRespond: [Notice]

    /// 今日の通知の時刻を過ぎていて、今日の日付の体重記録も今日の知らせも無ければ、今日の知らせ
    public let noticeToIssue: Notice?

    /// 今日から6日先までの7日分、1日1つ。今日の時刻が過ぎた分と、その日付の体重記録がある日の分は外す
    public let reminders: [MissedWeightRecordReminder]

    /// 開いているあいだに、次に知らせを出すかを決める時刻。今より後の、体重記録の無い日の通知の時刻のうち、いちばん早いもの。
    /// 今日の時刻を過ぎたか今日の体重記録があれば、明日以降の時刻になる（開いたまま日付が変わったときのため）
    public var nextNoticeTime: Date? { reminders.first?.fireDate }

    /// 通知センターに残った通知のうち、体重記録のある日の分
    public func deliveredIdsToRemove(from delivered: [UUID]) -> [UUID] {
        delivered.filter(recordedDayIds.contains)
    }

    private let recordedDayIds: Set<UUID>

    private static func id(on day: CalendarDay) -> UUID {
        Notice.id(kind: .missedWeightRecord, targetDay: day)
    }

    /// その日の通知の時刻（今のタイムゾーン）。Calendar が時刻を出せなければ nil
    private static func reminder(
        on day: CalendarDay, at clockTime: ClockTime, in timeZone: TimeZone
    ) -> MissedWeightRecordReminder? {
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
        return MissedWeightRecordReminder(
            id: id(on: day), day: day, clockTime: clockTime, fireDate: fireDate)
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
