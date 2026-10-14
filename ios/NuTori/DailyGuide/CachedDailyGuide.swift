import Foundation
import NuToriCore
import SwiftData

/// 1日の目安。目標と推定消費カロリーより先に届くこともあるので、それぞれの ID を値で持つ
@Model
nonisolated final class CachedDailyGuide {
    @Attribute(.unique) var guideId: UUID
    var goalId: UUID
    var expenditureEstimateId: UUID
    /// YYYY-MM-DD
    var effectiveDay: String
    var energyKilocalories: Int
    var proteinGrams: Int
    var fatGrams: Int
    var carbohydrateGrams: Int
    /// weekly_change・required_pace・minimum_energy。当たったものだけが並ぶ
    var limitHits: [String]

    init(_ guide: DailyGuide) {
        guideId = guide.id
        goalId = guide.goalId
        expenditureEstimateId = guide.expenditureEstimateId
        effectiveDay = guide.effectiveDay.yearMonthDay
        energyKilocalories = guide.energyKilocalories
        proteinGrams = guide.proteinGrams
        fatGrams = guide.fatGrams
        carbohydrateGrams = guide.carbohydrateGrams
        limitHits = guide.limitHits.map(Self.stored)
    }

    /// 1日の目安は変わらないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ guide: DailyGuide) {
        goalId = guide.goalId
        expenditureEstimateId = guide.expenditureEstimateId
        effectiveDay = guide.effectiveDay.yearMonthDay
        energyKilocalories = guide.energyKilocalories
        proteinGrams = guide.proteinGrams
        fatGrams = guide.fatGrams
        carbohydrateGrams = guide.carbohydrateGrams
        limitHits = guide.limitHits.map(Self.stored)
    }

    /// 読めない日付の行は nil。読めない上限・下限は外して、目安は読む（1日の丸を目安と比べ続けるため）
    func dailyGuide() -> DailyGuide? {
        guard let effectiveDay = CalendarDay(yearMonthDay: effectiveDay) else { return nil }
        return DailyGuide(
            id: guideId, goalId: goalId, expenditureEstimateId: expenditureEstimateId,
            effectiveDay: effectiveDay, energyKilocalories: energyKilocalories,
            proteinGrams: proteinGrams, fatGrams: fatGrams, carbohydrateGrams: carbohydrateGrams,
            limitHits: limitHits.compactMap(Self.limitHit))
    }

    private static func limitHit(_ stored: String) -> DailyGuide.LimitHit? {
        switch stored {
        case "weekly_change": .weeklyChange
        case "required_pace": .requiredPace
        case "minimum_energy": .minimumEnergy
        default: nil
        }
    }

    private static func stored(_ limitHit: DailyGuide.LimitHit) -> String {
        switch limitHit {
        case .weeklyChange: "weekly_change"
        case .requiredPace: "required_pace"
        case .minimumEnergy: "minimum_energy"
        }
    }
}
