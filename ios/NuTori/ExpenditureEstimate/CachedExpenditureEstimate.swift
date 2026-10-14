import Foundation
import NuToriCore
import SwiftData

/// 推定消費カロリー
@Model
nonisolated final class CachedExpenditureEstimate {
    @Attribute(.unique) var estimateId: UUID
    /// YYYY-MM-DD
    var effectiveDay: String
    var expenditureKilocalories: Int
    var estimatedAt: Date
    /// back_calculated・formula。推定の始まりだけにある
    var initialSource: String?

    init(_ estimate: ExpenditureEstimate) {
        estimateId = estimate.id
        effectiveDay = estimate.effectiveDay.yearMonthDay
        expenditureKilocalories = estimate.expenditureKilocalories
        estimatedAt = estimate.estimatedAt
        initialSource = estimate.initialSource.map(Self.stored)
    }

    /// 推定は変わらないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ estimate: ExpenditureEstimate) {
        effectiveDay = estimate.effectiveDay.yearMonthDay
        expenditureKilocalories = estimate.expenditureKilocalories
        estimatedAt = estimate.estimatedAt
        initialSource = estimate.initialSource.map(Self.stored)
    }

    /// 読めない日付・出どころの行は nil
    func expenditureEstimate() -> ExpenditureEstimate? {
        guard let effectiveDay = CalendarDay(yearMonthDay: effectiveDay) else { return nil }
        // 推定の始まりでない推定は出どころを持たない
        let source: ExpenditureEstimate.InitialSource?
        switch initialSource {
        case nil: source = nil
        case "back_calculated": source = .backCalculated
        case "formula": source = .formula
        default: return nil
        }
        return ExpenditureEstimate(
            id: estimateId, effectiveDay: effectiveDay,
            expenditureKilocalories: expenditureKilocalories, estimatedAt: estimatedAt,
            initialSource: source)
    }

    private static func stored(_ source: ExpenditureEstimate.InitialSource) -> String {
        switch source {
        case .backCalculated: "back_calculated"
        case .formula: "formula"
        }
    }
}
