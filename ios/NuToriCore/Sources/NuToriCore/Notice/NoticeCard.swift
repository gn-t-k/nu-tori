import Foundation

/// タイムラインに置く知らせと、その形。答えた知らせは `Timeline` が外してから作るので、答えていない知らせの形だけを持つ
public struct NoticeCard: Hashable, Sendable {
    public let notice: Notice
    public let form: Form

    public init(notice: Notice, form: Form) {
        self.notice = notice
        self.form = form
    }

    /// 対象の日付が今日なら、中で記録できる形にする。前の日の分から記録すると今日の体重になってしまうため
    init(unanswered notice: Notice, today: CalendarDay) {
        self.init(
            notice: notice, form: notice.targetDay == today ? .awaitingAnswer : .unansweredPastDay)
    }

    /// 1行目に出す時刻。出したときのタイムゾーンの時計の時刻
    public var clockTime: ClockTime {
        ClockTime(containing: notice.issuedAt, in: notice.timeZone)
    }

    public enum Form: Hashable, Sendable {
        /// 今日の答えていない知らせ。中で体重を記録できる
        case awaitingAnswer
        /// 前の日の答えていない知らせ。文だけを残す
        case unansweredPastDay
    }
}
