public import Foundation

/// 週の見直し（見送りを含む）。サーバーだけが書き、消えない。記録の ID は見直しの ID。
/// 指す推定消費カロリー・1日の目安・目標より先に届くことがある
public struct SyncedWeeklyReview: Sendable, Equatable {
    public let id: UUID
    /// 新しい1日の目安を当てる月曜（YYYY-MM-DD）。見直す入力の月〜日はその前の週
    public let effectiveOn: String
    public let reviewedAt: Date
    /// 見直しを起こした要求のタイムゾーン
    public let timeZone: TimeZone
    public let outcome: Outcome

    public init(
        id: UUID, effectiveOn: String, reviewedAt: Date, timeZone: TimeZone, outcome: Outcome
    ) {
        self.id = id
        self.effectiveOn = effectiveOn
        self.reviewedAt = reviewedAt
        self.timeZone = timeZone
        self.outcome = outcome
    }

    /// 見直せたか見送ったか。どちらか一方だけが付く
    public enum Outcome: Sendable, Equatable {
        case reviewed(expenditureEstimateId: UUID, dailyGuideId: UUID, mainReason: MainReason)
        /// 推定消費カロリーも1日の目安も前の週のまま。`goalId` はその週に当てた目標
        case deferred(reason: DeferralReason, goalId: UUID)
    }

    /// サーバーの `mainReason` の値。1日の目安が変わった主な理由
    public enum MainReason: String, Sendable, Equatable {
        /// 推定消費カロリーの変化
        case expenditureChange = "expenditure_change"
        /// 1日に減らす（足す）分の変化
        case balanceChange = "balance_change"
    }

    /// サーバーの見送りの `reason` の値
    public enum DeferralReason: String, Sendable, Equatable {
        /// 使い始めて7日未満
        case withinFirstWeek = "within_first_week"
        /// 体重が無い
        case noWeight = "no_weight"
        /// 食事の記録が少ない
        case fewMealRecords = "few_meal_records"
    }
}
