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
        guard let effectiveDay = CalendarDay(yearMonthDay: effectiveDay),
            let source = Self.initialSource(initialSource)
        else { return nil }
        return ExpenditureEstimate(
            id: estimateId, effectiveDay: effectiveDay,
            expenditureKilocalories: expenditureKilocalories, estimatedAt: estimatedAt,
            initialSource: source)
    }

    /// 読めない出どころは nil。推定の始まりでない推定（出どころを持たない）は `.some(nil)`
    private static func initialSource(_ stored: String?) -> ExpenditureEstimate.InitialSource?? {
        switch stored {
        case nil: .some(nil)
        case "back_calculated": ExpenditureEstimate.InitialSource.backCalculated
        case "formula": ExpenditureEstimate.InitialSource.formula
        default: nil
        }
    }

    private static func stored(_ source: ExpenditureEstimate.InitialSource) -> String {
        switch source {
        case .backCalculated: "back_calculated"
        case .formula: "formula"
        }
    }
}
