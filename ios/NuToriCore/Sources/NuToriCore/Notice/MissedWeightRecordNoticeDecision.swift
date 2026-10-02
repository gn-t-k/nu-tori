public import Foundation

/// 体重の知らせを出すか・答えるかの判断。キャッシュの値と今の時刻から、作る書き込み・答える書き込みの元を返す
public enum MissedWeightRecordNoticeDecision {
    /// 今日の通知の時刻を過ぎていて、今日の日付の体重記録も今日の知らせも無ければ、今日の知らせを返す。
    /// 過ぎた日の分は作らない（アプリを開かなかった日の知らせを、あとから出さない）
    public static func noticeToIssue(
        usualWeighingTime: UsualWeighingTime?,
        now: Date,
        timeZone: TimeZone,
        weightRecords: [WeightRecord],
        notices: [Notice]
    ) -> Notice? {
        let today = CalendarDay(containing: now, in: timeZone)
        guard
            let reminder = MissedWeightRecordReminder(
                day: today, usualWeighingTime: usualWeighingTime, in: timeZone),
            reminder.fireDate <= now,
            !weightRecords.contains(where: { $0.day == today }),
            !notices.contains(where: { $0.id == reminder.id })
        else {
            return nil
        }
        return Notice(
            id: reminder.id,
            kind: .missedWeightRecord,
            issuedAt: reminder.fireDate,
            timeZone: timeZone,
            targetDay: today,
            response: nil
        )
    }

    /// アプリを開いているあいだに、次に知らせを出すかを決める時刻。今より後の、体重記録の無い日の通知の時刻のうち、いちばん早いもの。
    /// 今日の時刻を過ぎたか今日の体重記録があれば、明日以降の時刻になる（開いたまま日付が変わったときのため）
    public static func nextNoticeTime(
        usualWeighingTime: UsualWeighingTime?,
        now: Date,
        timeZone: TimeZone,
        weightRecords: [WeightRecord]
    ) -> Date? {
        MissedWeightRecordReminder.plan(
            usualWeighingTime: usualWeighingTime, now: now, timeZone: timeZone,
            weightRecords: weightRecords
        )
        .first?.fireDate
    }

    /// 答えていない知らせのうち、対象の日付の体重記録があるものの ID。
    /// 日付の決め方は、通知の取り消しの日の決まりと同じ（体重記録は記録したときのタイムゾーンでの日付）
    public static func noticeIdsToRespond(notices: [Notice], weightRecords: [WeightRecord])
        -> [UUID]
    {
        let recordedDays = Set(weightRecords.map(\.day))
        return
            notices
            .filter { $0.response == nil && recordedDays.contains($0.targetDay) }
            .map(\.id)
    }
}
