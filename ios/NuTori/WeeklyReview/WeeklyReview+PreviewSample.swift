#if DEBUG
    import Foundation
    import NuToriCore

    /// プレビューの見本の、9月14日（月）に立てた減量の目標（`Goal.sampleWeeklyReviewed`）の1週目を、9月24日（木）の 6:10 に見直した場面
    extension WeeklyReview {
        /// 1日の目安を 1,880 kcal から 1,850 kcal に下げた見直し。主な理由は推定消費カロリーの変化
        static let sampleReviewed = WeeklyReview(
            id: sampleId, effectiveDay: sampleMonday, reviewedAt: sampleReviewedAt,
            timeZone: sampleTimeZone,
            outcome: .reviewed(
                expenditureEstimateId: ExpenditureEstimate.sampleReviewed.id,
                dailyGuideId: DailyGuide.sampleReviewed.id, mainReason: .expenditureChange))

        /// 食事の記録が少なくて見送った見直し
        static let sampleDeferred = WeeklyReview(
            id: sampleId, effectiveDay: sampleMonday, reviewedAt: sampleReviewedAt,
            timeZone: sampleTimeZone,
            outcome: .deferred(reason: .fewMealRecords, goalId: Goal.sampleWeeklyReviewed.id))

        /// 見直しを当てる週の月曜
        static let sampleMonday = CalendarDay(year: 2026, month: 9, day: 21)

        static let sampleReviewedAt: Date = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = sampleTimeZone
            return calendar.date(
                from: DateComponents(year: 2026, month: 9, day: 24, hour: 6, minute: 10))!
        }()

        private static let sampleId = UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000F1")!

        private static let sampleTimeZone = TimeZone(identifier: "Asia/Tokyo")!
    }
#endif
