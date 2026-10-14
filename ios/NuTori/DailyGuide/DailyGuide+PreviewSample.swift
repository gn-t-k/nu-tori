#if DEBUG
    import Foundation
    import NuToriCore

    extension DailyGuide {
        /// プレビューの見本の1日の目安（1,850 kcal、P 130 g・F 50 g・C 220 g）。その目標の開始の日から当てる
        static func sample(for goal: Goal) -> DailyGuide {
            DailyGuide(
                id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000D1")!, goalId: goal.id,
                expenditureEstimateId: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000E1")!,
                effectiveDay: goal.startedDay, energyKilocalories: 1850, proteinGrams: 130,
                fatGrams: 50, carbohydrateGrams: 220, limitHits: [])
        }
    }
#endif
