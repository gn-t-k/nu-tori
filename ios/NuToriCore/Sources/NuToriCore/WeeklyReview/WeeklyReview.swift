public import Foundation

/// 週の見直し（見送りを含む）。サーバーだけが書き、消えない。
/// 指す推定消費カロリー・1日の目安・目標より先に届くことがあるので、描く側は指す記録が届くまで変更の知らせを描かない
public struct WeeklyReview: Hashable, Sendable {
    public let id: UUID
    /// 新しい1日の目安を当てる月曜。見直す入力の月〜日はその前の週
    public let effectiveDay: CalendarDay
    public let reviewedAt: Date
    /// 見直しを起こした要求のタイムゾーン
    public let timeZone: TimeZone
    public let outcome: Outcome

    /// 見直すのに要る、食事を記録した日の数。これより少ない週は見送る。文に出すだけで判定には使わない。正本はサーバーの `minimumMealDays`（`judge-review-week.ts`）
    static let minimumMealDayCount = 4

    public init(
        id: UUID, effectiveDay: CalendarDay, reviewedAt: Date, timeZone: TimeZone,
        outcome: Outcome
    ) {
        self.id = id
        self.effectiveDay = effectiveDay
        self.reviewedAt = reviewedAt
        self.timeZone = timeZone
        self.outcome = outcome
    }

    /// 見直せたか見送ったか
    public enum Outcome: Hashable, Sendable {
        case reviewed(expenditureEstimateId: UUID, dailyGuideId: UUID, mainReason: MainReason)
        /// 推定消費カロリーも1日の目安も前の週のまま。`goalId` はその週に当てた目標
        case deferred(reason: DeferralReason, goalId: UUID)
    }

    /// 1日の目安が変わった主な理由
    public enum MainReason: Hashable, Sendable {
        /// 推定消費カロリーの変化
        case expenditureChange
        /// 1日に減らす（足す）分の変化
        case balanceChange
    }

    /// 見送りの理由
    public enum DeferralReason: Hashable, Sendable {
        /// 使い始めて7日未満
        case withinFirstWeek
        /// 体重が無い
        case noWeight
        /// 食事の記録が少ない
        case fewMealRecords
    }
}
