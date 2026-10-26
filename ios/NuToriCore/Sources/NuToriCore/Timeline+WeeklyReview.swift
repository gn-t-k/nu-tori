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
        let weightRecordDays = input.goalRecords.weightRecords.map(\.day)
        return Dictionary(grouping: input.goalRecords.weeklyReviews, by: \.reviewedAt).values
            .compactMap {
                reviews in
                let batch = reviews.sorted { $0.effectiveDay < $1.effectiveDay }
                guard let latest = batch.last else { return nil }
                let monday = latest.effectiveDay.advanced(by: -7)
                let sunday = latest.effectiveDay.advanced(by: -1)
                guard
                    let goal = DailyGuideForDay(
                        on: sunday, goals: input.goalRecords.goals,
                        dailyGuides: input.goalRecords.dailyGuides)?.goal
                else { return nil }
                let card = WeeklyReviewCard(
                    review: latest,
                    days: max(monday, goal.startedDay)...sunday,
                    rings: (0..<7).map { offset in
                        let day = monday.advanced(by: offset)
                        return day < firstDay ? .beforeFirstDay(day) : .ring(day, ring(day))
                    },
                    pace: WeeklyReviewCard.PaceLine(
                        goal: goal, sunday: sunday, weightTrend: input.goalRecords.weightTrend,
                        weightRecordDays: weightRecordDays),
                    otherReviewedWeekCount: batch.count - 1)
                return WeeklyReviewItems(
                    card: card,
                    changeNotice: changeNotice(batch: batch, records: input.goalRecords),
                    day: max(
                        CalendarDay(containing: latest.reviewedAt, in: latest.timeZone), firstDay))
            }
    }

    /// まとめた最初の週の前の1日の目安と、いちばん新しく見直せた週の1日の目安で比べる。理由の種類は、いちばん新しく見直せた週の主な理由
    /// - Parameter batch: 同じ時刻に見直した週。古い順
    private static func changeNotice(batch: [WeeklyReview], records: GoalRecords)
        -> DailyGuideChangeNotice?
    {
        let reviewedWeeks = batch.compactMap {
            review -> (guideId: UUID, mainReason: WeeklyReview.MainReason)? in
            switch review.outcome {
            case .reviewed(_, let guideId, let mainReason): (guideId, mainReason)
            case .deferred: nil
            }
        }
        guard let first = batch.first, let latest = batch.last,
            let reviewed = reviewedWeeks.last,
            let guide = records.dailyGuides.first(where: { $0.id == reviewed.guideId }),
            let goal = records.goals.first(where: { $0.id == guide.goalId }),
            // 月曜に立て直した週の、前の目標に書いた1日の目安は1日も当たらない
            goal.closure.map({ $0.endedDay > guide.effectiveDay }) ?? true,
            let previousGuide = DailyGuideForDay(
                on: first.effectiveDay.advanced(by: -1), goals: records.goals,
                dailyGuides: records.dailyGuides)?.dailyGuide,
            let reason = DailyGuideChangeReason(
                mainReason: reviewed.mainReason, from: previousGuide, to: guide, records: records)
        else { return nil }
        return DailyGuideChangeNotice(
            review: latest, dailyGuide: guide,
            changeKilocalories: guide.energyKilocalories - previousGuide.energyKilocalories,
            reason: reason)
    }
}
