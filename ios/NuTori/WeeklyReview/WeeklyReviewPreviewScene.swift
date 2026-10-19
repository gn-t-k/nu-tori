#if DEBUG
    import Foundation
    import NuToriCore

    /// プレビューの見本の、9月14日（月）に立てた減量の目標の1週目を、9月24日（木）の 6:10 に見直した場面。
    /// 1日の目安は 1,880 kcal から 1,850 kcal に、推定消費カロリーは 2,190 kcal から 2,140 kcal に下がった
    enum WeeklyReviewPreviewScene {
        static let goal = Goal.sampleLosing(startedOn: CalendarDay(year: 2026, month: 9, day: 14))

        static let firstEstimate = ExpenditureEstimate(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000E1")!,
            effectiveDay: goal.startedDay, expenditureKilocalories: 2190,
            estimatedAt: goal.decidedAt, initialSource: .backCalculated)

        static let reviewedEstimate = ExpenditureEstimate(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000E2")!,
            effectiveDay: monday, expenditureKilocalories: 2140, estimatedAt: reviewedAt,
            initialSource: nil)

        static let firstGuide = DailyGuide(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000D1")!, goalId: goal.id,
            expenditureEstimateId: firstEstimate.id, effectiveDay: goal.startedDay,
            energyKilocalories: 1880, proteinGrams: 130, fatGrams: 52, carbohydrateGrams: 222,
            limitHits: [])

        static let reviewedGuide = DailyGuide(
            id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000D2")!, goalId: goal.id,
            expenditureEstimateId: reviewedEstimate.id, effectiveDay: monday,
            energyKilocalories: 1850, proteinGrams: 130, fatGrams: 50, carbohydrateGrams: 220,
            limitHits: [])

        /// - Parameter deferred: 食事の記録が少なくて見送った週にする
        static func review(deferred: Bool = false) -> WeeklyReview {
            WeeklyReview(
                id: UUID(uuidString: "6F1C2A40-0000-4000-8000-0000000000F1")!,
                effectiveDay: monday, reviewedAt: reviewedAt, timeZone: timeZone,
                outcome: deferred
                    ? .deferred(reason: .fewMealRecords, goalId: goal.id)
                    : .reviewed(
                        expenditureEstimateId: reviewedEstimate.id,
                        dailyGuideId: reviewedGuide.id, mainReason: .expenditureChange))
        }

        /// 見直した週の月〜日の体重記録（水・金・土）と、日ごとに推定できた食事
        static let weightRecords: [WeightRecord] = [2, 4, 5].map {
            .sample(
                72.2 - Double($0) * 0.1, on: goal.startedDay.advanced(by: $0), at: 7, 0,
                from: .manual)
        }

        static let meals: [MealCard] = [0, 1, 2, 4, 5].map {
            .sampleEstimated(.sample(on: goal.startedDay.advanced(by: $0), at: 12, 10))
        }

        static let weightTrend = WeightTrend(
            days: (0..<10).map {
                WeightTrend.Day(
                    day: goal.startedDay.advanced(by: $0), kilograms: 72.4 - Double($0) * 0.05)
            })

        /// 振り返りのカードと変更の知らせを組むタイムライン
        static func timeline(deferred: Bool = false) -> Timeline {
            Timeline(
                input: Timeline.Input(
                    weightRecords: weightRecords, rejectedLines: [], meals: meals, notices: [],
                    undelivered: .none, conversation: .none, goals: [goal],
                    dailyGuides: [firstGuide, reviewedGuide],
                    weeklyReviews: [review(deferred: deferred)],
                    expenditureEstimates: [firstEstimate, reviewedEstimate],
                    weightTrend: weightTrend),
                firstDay: goal.startedDay, today: .sampleToday)
        }

        static let monday = CalendarDay(year: 2026, month: 9, day: 21)

        private static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

        private static var reviewedAt: Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(
                from: DateComponents(year: 2026, month: 9, day: 24, hour: 6, minute: 10))!
        }
    }
#endif
