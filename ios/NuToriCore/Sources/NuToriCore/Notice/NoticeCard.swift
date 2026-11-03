import Foundation

/// タイムラインに置く体重の知らせ（記録忘れの知らせ）と、その形。答えた知らせは `Timeline` が外してから作るので、答えていない知らせの形だけを持つ
public struct NoticeCard: Hashable, Sendable {
    public let notice: Notice
    public let form: Form

    public init(notice: Notice, form: Form) {
        self.notice = notice
        self.form = form
    }

    /// 対象の日付が今日なら、中で記録できる形にする。前の日の分から記録すると今日の体重になってしまうため。
    /// 対象の日付を持たない知らせ（目標を立てる）は体重の知らせでないので nil
    init?(unanswered notice: Notice, today: CalendarDay) {
        guard case .missedWeightRecord(let targetDay) = notice.kind else { return nil }
        self.init(
            notice: notice,
            form: targetDay == today ? .awaitingAnswer : .unansweredPastDay(targetDay: targetDay))
    }

    /// 見出しの下の文。知らせには時刻を付けないので（DESIGN.md の own-record-time）、いつもの時刻は文の中に書く
    public var body: String {
        "いつもは \(WeightAmountText.clock(clockTime)) までに記録しています。"
    }

    public enum Form: Hashable, Sendable {
        /// 今日の答えていない知らせ。中で体重を記録できる
        case awaitingAnswer
        /// 前の日の答えていない知らせ。文だけを残す。見出しに対象の日付を書く
        case unansweredPastDay(targetDay: CalendarDay)
    }

    /// 文に書く時刻。出したときのタイムゾーンの時計の時刻
    private var clockTime: ClockTime {
        ClockTime(containing: notice.issuedAt, in: notice.timeZone)
    }
}
