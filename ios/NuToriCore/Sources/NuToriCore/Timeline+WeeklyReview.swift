import Foundation

extension Timeline {
    /// 同じ時刻にまとめて見直した週ごとの、振り返りのカードと変更の知らせ
    struct WeeklyReviewItems {
        let card: WeeklyReviewCard
        /// 見送った週と、指す記録がまだ届いていない週と、1日も当たらない1日の目安の週は nil
        let changeNotice: DailyGuideChangeNotice?
        /// 見直したときのタイムゾーンの日。使い始めた日より前なら使い始めた日
        let day: CalendarDay
    }

    /// 週の見直しの記録から、振り返りのカードと変更の知らせを組む。見直した週に当たっていた目標がまだ届いていなければ（目標がないあいだも）出さない
    /// - Parameter ring: その日の1日の丸。タイムラインの丸と同じもの
    static func weeklyReviewItems(
        input: Input, firstDay: CalendarDay, ring: (CalendarDay) -> DayRing
    ) -> [WeeklyReviewItems] {
        let weightRecordDays = input.weightRecords.map(\.day)
        return Dictionary(grouping: input.weeklyReviews, by: \.reviewedAt).values.compactMap {
            reviews in
            let batch = reviews.sorted { $0.effectiveDay < $1.effectiveDay }
            guard let latest = batch.last else { return nil }
            let monday = latest.effectiveDay.advanced(by: -7)
            let sunday = latest.effectiveDay.advanced(by: -1)
            guard
                let goal = DailyGuideForDay(
                    on: sunday, goals: input.goals, dailyGuides: input.dailyGuides)?.goal
            else { return nil }
            let card = WeeklyReviewCard(
                review: latest,
                days: max(monday, goal.startedDay)...sunday,
                rings: (0..<7).map { offset in
                    let day = monday.advanced(by: offset)
                    return day < firstDay ? .beforeFirstDay(day) : .ring(day, ring(day))
                },
                pace: WeeklyReviewCard.PaceLine(
                    goal: goal, sunday: sunday, weightTrend: input.weightTrend,
                    weightRecordDays: weightRecordDays),
                otherReviewedWeekCount: batch.count - 1)
            return WeeklyReviewItems(
                card: card, changeNotice: changeNotice(batch: batch, input: input),
                day: max(CalendarDay(containing: latest.reviewedAt, in: latest.timeZone), firstDay))
        }
    }

    /// まとめた最初の週の前の1日の目安と、いちばん新しく見直せた週の1日の目安で比べる
    /// - Parameter batch: 同じ時刻に見直した週。古い順
    private static func changeNotice(batch: [WeeklyReview], input: Input)
        -> DailyGuideChangeNotice?
    {
        let reviewedWeeks = batch.compactMap {
            review -> (estimateId: UUID, guideId: UUID, mainReason: WeeklyReview.MainReason)? in
            switch review.outcome {
            case .reviewed(let estimateId, let guideId, let mainReason):
                (estimateId, guideId, mainReason)
            case .deferred: nil
            }
        }
        guard let first = batch.first, let latest = batch.last,
            let reviewed = reviewedWeeks.last,
            let guide = input.dailyGuides.first(where: { $0.id == reviewed.guideId }),
            let estimate = input.expenditureEstimates.first(where: { $0.id == reviewed.estimateId }
            ),
            let goal = input.goals.first(where: { $0.id == guide.goalId }),
            // 月曜に立て直した週の、前の目標に書いた1日の目安は1日も当たらない
            goal.closure.map({ $0.endedDay > guide.effectiveDay }) ?? true,
            let previous = DailyGuideForDay(
                on: first.effectiveDay.advanced(by: -1), goals: input.goals,
                dailyGuides: input.dailyGuides),
            let previousGuide = previous.dailyGuide,
            let previousEstimate = input.expenditureEstimates.first(where: {
                $0.id == previousGuide.expenditureEstimateId
            })
        else { return nil }
        let expenditureChange =
            estimate.expenditureKilocalories - previousEstimate.expenditureKilocalories
        let balanceChange =
            (estimate.expenditureKilocalories - guide.energyKilocalories)
            - (previousEstimate.expenditureKilocalories - previousGuide.energyKilocalories)
        // 見直せた週が1つなら、サーバーが決めた主な理由を使う。何週分もまとめた変化は、同じ決まり（同じ大きさなら推定消費カロリー）で比べ直す
        let mainReason =
            reviewedWeeks.count == 1
            ? reviewed.mainReason
            : abs(expenditureChange) >= abs(balanceChange) ? .expenditureChange : .balanceChange
        let balance = DailyGuideChangeNotice.Balance(goal.direction)
        let reason: DailyGuideChangeNotice.Reason =
            if previous.goal.id != goal.id,
                previous.goal.closure?.endReason == .movedToMaintenance
            {
                .movedToMaintenance
            } else {
                switch mainReason {
                case .expenditureChange:
                    .expenditureChanged(
                        fromKilocalories: previousEstimate.expenditureKilocalories,
                        toKilocalories: estimate.expenditureKilocalories)
                case .balanceChange:
                    if let achievement = goal.achievement,
                        achievement.achievedDay < guide.effectiveDay
                    {
                        .achieved(balance)
                    } else {
                        .balanceChanged(
                            balance,
                            increased: abs(
                                estimate.expenditureKilocalories - guide.energyKilocalories)
                                > abs(
                                    previousEstimate.expenditureKilocalories
                                        - previousGuide.energyKilocalories))
                    }
                }
            }
        return DailyGuideChangeNotice(
            review: latest, dailyGuide: guide,
            changeKilocalories: guide.energyKilocalories - previousGuide.energyKilocalories,
            reason: reason,
            batch: batch.count > 1
                ? DailyGuideChangeNotice.Batch(
                    firstWeekMonday: first.effectiveDay.advanced(by: -7), weekCount: batch.count)
                : nil)
    }
}
