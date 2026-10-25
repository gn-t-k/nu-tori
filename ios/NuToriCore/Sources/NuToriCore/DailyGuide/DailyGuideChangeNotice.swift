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

    public init(
        review: WeeklyReview, dailyGuide: DailyGuide, changeKilocalories: Int,
        reason: DailyGuideChangeReason
    ) {
        self.review = review
        self.dailyGuide = dailyGuide
        self.changeKilocalories = changeKilocalories
        self.reason = reason
    }

    /// 「−30 kcal」
    public var changeText: String {
        GoalText.signedKilocalories(changeKilocalories)
    }

    public var reasonText: String {
        reason.text
    }
}
