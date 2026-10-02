import Foundation

/// タイムラインに置く知らせと、その形
public struct NoticeCard: Hashable, Sendable {
    public let notice: Notice
    public let form: Form

    public init(notice: Notice, form: Form) {
        self.notice = notice
        self.form = form
    }

    /// 対象の日付が今日なら、答えていない知らせは中で記録できる形にする。前の日の分から記録すると今日の体重になってしまうため
    init(notice: Notice, today: CalendarDay) {
        let form: Form =
            if notice.response != nil {
                .answered
            } else if notice.targetDay == today {
                .awaitingAnswer
            } else {
                .unansweredPastDay
            }
        self.init(notice: notice, form: form)
    }

    /// 1行目に出す時刻。出したときのタイムゾーンの時計の時刻
    public var clockTime: ClockTime {
        ClockTime(containing: notice.issuedAt, in: notice.timeZone)
    }

    public enum Form: Hashable, Sendable {
        /// 今日の答えていない知らせ。中で体重を記録できる
        case awaitingAnswer
        case answered
        /// 前の日の答えていない知らせ。文だけを残す
        case unansweredPastDay
    }
}
