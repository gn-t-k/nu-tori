import Foundation

/// 1日の目安の変更の知らせ。振り返りのカードのすぐ下に置き、答えを持たない。
/// まとめて見直したときは、まとめた最初の週の前の1日の目安と、いちばん新しい1日の目安で比べる
public struct DailyGuideChangeNotice: Hashable, Sendable {
    /// まとめて見直した週のうち、いちばん新しい週の見直し。知らせの時刻と置く位置はこれで決める
    public let review: WeeklyReview
    /// 新しい1日の目安
    public let dailyGuide: DailyGuide
    /// 新しい1日の目安 − 前の1日の目安
    public let changeKilocalories: Int
    public let reason: DailyGuideChangeReason
    /// まとめて見直したときだけ持つ
    public let batch: Batch?

    public init(
        review: WeeklyReview, dailyGuide: DailyGuide, changeKilocalories: Int,
        reason: DailyGuideChangeReason,
        batch: Batch?
    ) {
        self.review = review
        self.dailyGuide = dailyGuide
        self.changeKilocalories = changeKilocalories
        self.reason = reason
        self.batch = batch
    }

    /// 「−30 kcal」
    public var changeText: String {
        GoalText.signedKilocalories(changeKilocalories)
    }

    public var reasonText: String {
        reason.text
    }

    public var batchText: String? {
        batch.map {
            "\(GoalText.monthDay($0.firstWeekMonday))からの \($0.weekCount) 週分の見直しをまとめた値です。"
        }
    }

    public struct Batch: Hashable, Sendable {
        /// まとめた最初の週の月曜
        public let firstWeekMonday: CalendarDay
        public let weekCount: Int

        public init(firstWeekMonday: CalendarDay, weekCount: Int) {
            self.firstWeekMonday = firstWeekMonday
            self.weekCount = weekCount
        }
    }
}
