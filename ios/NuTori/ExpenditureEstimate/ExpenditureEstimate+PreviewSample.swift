#if DEBUG
    import Foundation
    import NuToriCore

    extension ExpenditureEstimate {
        /// プレビューの見本の、`Goal.sampleWeeklyReviewed` を立てたときに逆算した推定消費カロリー（2,190 kcal）
        static let sampleFirst = ExpenditureEstimate(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000E1")!,
            effectiveDay: Goal.sampleWeeklyReviewed.startedDay, expenditureKilocalories: 2190,
            estimatedAt: Goal.sampleWeeklyReviewed.decidedAt, initialSource: .backCalculated)

        /// プレビューの見本の、`WeeklyReview.sampleReviewed` で見直した推定消費カロリー（2,140 kcal）
        static let sampleReviewed = ExpenditureEstimate(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000E2")!,
            effectiveDay: WeeklyReview.sampleMonday, expenditureKilocalories: 2140,
            estimatedAt: WeeklyReview.sampleReviewedAt, initialSource: nil)
    }
#endif
