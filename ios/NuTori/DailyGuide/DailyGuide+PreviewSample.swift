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

        /// プレビューの見本の、`Goal.sampleWeeklyReviewed` を立てたときの1日の目安（1,880 kcal）
        static let sampleFirst = DailyGuide(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000D1")!,
            goalId: Goal.sampleWeeklyReviewed.id,
            expenditureEstimateId: ExpenditureEstimate.sampleFirst.id,
            effectiveDay: Goal.sampleWeeklyReviewed.startedDay, energyKilocalories: 1880,
            proteinGrams: 130, fatGrams: 52, carbohydrateGrams: 222, limitHits: [])

        /// プレビューの見本の、`WeeklyReview.sampleReviewed` で見直した1日の目安（1,850 kcal）
        static let sampleReviewed = DailyGuide(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000D2")!,
            goalId: Goal.sampleWeeklyReviewed.id,
            expenditureEstimateId: ExpenditureEstimate.sampleReviewed.id,
            effectiveDay: WeeklyReview.sampleMonday, energyKilocalories: 1850, proteinGrams: 130,
            fatGrams: 50, carbohydrateGrams: 220, limitHits: [])
    }
#endif
