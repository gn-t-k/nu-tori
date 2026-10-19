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
    public let reason: Reason
    /// まとめて見直したときだけ持つ
    public let batch: Batch?

    public init(
        review: WeeklyReview, dailyGuide: DailyGuide, changeKilocalories: Int, reason: Reason,
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
        NoticeAmountText.signedKilocalories(changeKilocalories)
    }

    public var reasonText: String {
        reason.text
    }

    public var batchText: String? {
        batch.map {
            "\(NoticeAmountText.monthDay($0.firstWeekMonday))からの \($0.weekCount) 週分の見直しをまとめた値です。"
        }
    }

    /// 1日の目安が変わった主な理由。当たった上限と下限は書かない
    public enum Reason: Hashable, Sendable {
        case expenditureChanged(fromKilocalories: Int, toKilocalories: Int)
        /// 1日に減らす（足す・戻す）分が増えた・減った
        case balanceChanged(Balance, increased: Bool)
        /// 目標に届いたので、1日に減らす（足す）分をなくしていく
        case achieved(Balance)
        /// 期限後の維持に移った
        case movedToMaintenance

        public var text: String {
            switch self {
            case .expenditureChanged(let from, let to):
                "推定消費カロリーが \(NoticeAmountText.kilocalories(from)) から \(NoticeAmountText.kilocalories(to)) kcal に\(to < from ? "下がった" : "上がった")ためです。"
            case .balanceChanged(.maintain, let increased):
                "1日に戻す分を\(increased ? "増やした" : "減らした")ためです。"
            case .balanceChanged(let balance, true):
                "期限までの日が減り、1日に\(balance.name)を増やしたためです。"
            case .balanceChanged(let balance, false):
                "体重の傾向が先に進み、1日に\(balance.name)を減らしたためです。"
            case .achieved(let balance):
                "目標に届いたので、1日に\(balance.name)をなくしていくためです。"
            case .movedToMaintenance:
                "今の体重を保つ目標に切り替えたためです。"
            }
        }
    }

    /// 1日に◯◯分。目標の向きで呼び分ける
    public enum Balance: Hashable, Sendable {
        case lose
        case gain
        case maintain

        init(_ direction: Goal.Direction) {
            switch direction {
            case .lose: self = .lose
            case .gain: self = .gain
            case .maintain: self = .maintain
            }
        }

        var name: String {
            switch self {
            case .lose: "減らす分"
            case .gain: "足す分"
            case .maintain: "戻す分"
            }
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
