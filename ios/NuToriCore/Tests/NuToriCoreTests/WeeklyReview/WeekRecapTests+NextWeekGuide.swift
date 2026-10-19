import Foundation
import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("1週目の見直しに使った記録")
    struct FirstWeekNote {
        @Test("立てた日より前を含めた月〜日を見直しに使ったと添えること")
        func notesReviewedWeek() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 1), today: WeekRecapTests.day(10, 10)))

            #expect(recap.firstWeekNote == "1日の目安の見直しには、9月28日〜10月4日の 7 日の記録を使っています。")
        }

        @Test("2週目からは添えないこと")
        func noNoteLater() throws {
            let recap = try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 13)))

            #expect(recap.firstWeekNote == nil)
        }
    }

    @Suite("次の週の1日の目安")
    struct NextWeekGuide {
        /// 10月12日〜18日の週と、10月19日から当てる見直し。前の1日の目安は 1,880 kcal（推定消費カロリー 2,190 kcal）
        static func recap(
            goal: Goal? = nil,
            outcome: (_ estimateId: UUID, _ guideId: UUID) -> WeeklyReview.Outcome,
            newGuideKilocalories: Int = 1850, newGuideGoalId: UUID? = nil,
            limitHits: [DailyGuide.LimitHit] = [], newGuideArrived: Bool = true,
            extraGoals: [Goal] = [], meals: [MealCard] = []
        ) throws -> WeekRecap {
            let goal = try goal ?? Goal.losing()
            let firstEstimate = ExpenditureEstimate(
                id: UUID(), effectiveDay: WeekRecapTests.day(10, 1),
                expenditureKilocalories: 2190, estimatedAt: goal.decidedAt,
                initialSource: .formula)
            let firstGuide = DailyGuide(
                id: UUID(), goalId: goal.id, expenditureEstimateId: firstEstimate.id,
                effectiveDay: WeekRecapTests.day(10, 1), energyKilocalories: 1880,
                proteinGrams: 120, fatGrams: 55, carbohydrateGrams: 230, limitHits: [])
            let reviewedAt = try Date("2026-10-19T07:00:00+09:00", strategy: .iso8601)
            let newEstimate = ExpenditureEstimate(
                id: UUID(), effectiveDay: WeekRecapTests.day(10, 19),
                expenditureKilocalories: 2140, estimatedAt: reviewedAt, initialSource: nil)
            let newGuide = DailyGuide(
                id: UUID(), goalId: newGuideGoalId ?? goal.id,
                expenditureEstimateId: newEstimate.id, effectiveDay: WeekRecapTests.day(10, 19),
                energyKilocalories: newGuideKilocalories, proteinGrams: 110, fatGrams: 50,
                carbohydrateGrams: 240, limitHits: limitHits)
            return try #require(
                try WeekRecapTests.recap(
                    weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 20),
                    goals: [goal] + extraGoals,
                    dailyGuides: [firstGuide] + (newGuideArrived ? [newGuide] : []),
                    expenditureEstimates: [firstEstimate, newEstimate],
                    weeklyReviews: [
                        WeeklyReview(
                            id: UUID(), effectiveDay: WeekRecapTests.day(10, 19),
                            reviewedAt: reviewedAt, timeZone: goal.timeZone,
                            outcome: outcome(newEstimate.id, newGuide.id))
                    ], meals: meals))
        }

        static func reviewed(_ mainReason: WeeklyReview.MainReason) -> (UUID, UUID) ->
            WeeklyReview.Outcome
        {
            { estimateId, guideId in
                .reviewed(
                    expenditureEstimateId: estimateId, dailyGuideId: guideId,
                    mainReason: mainReason)
            }
        }

        /// `Goal.losing()` を、10月19日の月曜に閉じたもの
        static func losingClosed(nextGoalId: UUID, endReason: Goal.EndReason) throws -> Goal {
            try Goal.losing(
                closure: Goal.Closure(
                    endedDay: WeekRecapTests.day(10, 19), nextGoalId: nextGoalId,
                    endReason: endReason))
        }

        /// 10月19日の月曜に始めた、70.5 kg を保つ目標
        static func maintainingFromMonday(id: UUID) throws -> Goal {
            try Goal.maintaining(
                id: id, startedOn: WeekRecapTests.day(10, 19), kilograms: 70.5,
                decidedAt: "2026-10-19T07:00:00+09:00")
        }

        @Suite("推定消費カロリーの変化で変わったとき")
        struct ExpenditureChange {
            let guide: WeekRecap.NextWeekGuide

            init() throws {
                guide = try #require(
                    try NextWeekGuide.recap(outcome: NextWeekGuide.reviewed(.expenditureChange))
                        .nextWeekGuide)
            }

            @Test("新しい値と変わった量を出すこと")
            func showsNewValueAndChange() {
                #expect(guide.energyKilocalories == 1850)
                #expect(guide.changeText == "−30 kcal")
            }

            @Test("前と新しい値と、推定消費カロリーが変わった理由を文にすること")
            func explainsExpenditure() {
                #expect(
                    guide.sentence
                        == "1,880 → 1,850 kcal。推定消費カロリーが 2,190 から 2,140 kcal に下がったためです。推移は目標で見られます。"
                )
            }
        }

        @Suite("1日に減らす分の変化で変わったとき")
        struct BalanceChange {
            @Test("1日に減らす分を増やしたときは、期限までの日が減ったことを理由にすること")
            func explainsBalance() throws {
                // 推定消費カロリー 2,190 → 2,140、1日に減らす分 310 → 390 kcal
                let guide = try #require(
                    try NextWeekGuide.recap(
                        outcome: NextWeekGuide.reviewed(.balanceChange), newGuideKilocalories: 1750
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 1,750 kcal。期限までの日が減り、1日に減らす分を増やしたためです。推移は目標で見られます。")
            }

            @Test("1日に減らす分を減らしたときは、予定より進んでいることを理由にすること")
            func explainsBalanceDecrease() throws {
                let guide = try #require(
                    try NextWeekGuide.recap(
                        outcome: NextWeekGuide.reviewed(.balanceChange), newGuideKilocalories: 1900
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 1,900 kcal。予定より進んでいるので、1日に減らす分を減らしたためです。推移は目標で見られます。")
            }

            @Test("維持で1日に戻す分を増やしたときは、体重の傾向に合わせたことを理由にすること")
            func explainsMaintenanceBalance() throws {
                let maintaining = try Goal.maintaining(
                    startedOn: WeekRecapTests.day(10, 1), kilograms: 72.4,
                    decidedAt: "2026-10-01T08:30:00+09:00")
                let guide = try #require(
                    try NextWeekGuide.recap(
                        goal: maintaining, outcome: NextWeekGuide.reviewed(.balanceChange),
                        newGuideKilocalories: 1800
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 1,800 kcal。体重の傾向に合わせて、1日に戻す分を増やしたためです。推移は目標で見られます。")
            }
        }

        @Suite("達成したあとに変わったとき")
        struct AfterAchievement {
            @Test("減らす分をなくしていくことを理由にすること")
            func explainsAchievement() throws {
                let goal = try Goal.losing(
                    achievement: .inTokyo(
                        on: WeekRecapTests.day(10, 15), judgedAt: "2026-10-15T07:10:00+09:00"))
                let guide = try #require(
                    try NextWeekGuide.recap(
                        goal: goal, outcome: NextWeekGuide.reviewed(.balanceChange),
                        newGuideKilocalories: 2000
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 2,000 kcal。目標に届いたので、1日に減らす分をなくしていくためです。推移は目標で見られます。")
            }
        }

        @Suite("期限後の維持に移ったとき")
        struct MovedToMaintenance {
            @Test("今の体重を保つ目標に切り替えたことを理由にすること")
            func explainsMaintenance() throws {
                let maintenanceId = UUID()
                let guide = try #require(
                    try NextWeekGuide.recap(
                        goal: try NextWeekGuide.losingClosed(
                            nextGoalId: maintenanceId, endReason: .movedToMaintenance),
                        outcome: NextWeekGuide.reviewed(.balanceChange),
                        newGuideKilocalories: 2000, newGuideGoalId: maintenanceId,
                        extraGoals: [try NextWeekGuide.maintainingFromMonday(id: maintenanceId)]
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 2,000 kcal。今の体重を保つ目標に切り替えたためです。推移は目標で見られます。")
            }
        }

        @Suite("上限と下限に当たったとき")
        struct LimitHits {
            @Test("当たった決まりを1つずつ文で足すこと")
            func explainsLimits() throws {
                let guide = try #require(
                    try NextWeekGuide.recap(
                        outcome: NextWeekGuide.reviewed(.expenditureChange),
                        limitHits: [.weeklyChange, .requiredPace, .minimumEnergy]
                    ).nextWeekGuide)

                #expect(
                    guide.sentence
                        == "1,880 → 1,850 kcal。推定消費カロリーが 2,190 から 2,140 kcal に下がったためです。推移は目標で見られます。1週間に変える量は 150 kcal までにしています。減らす速さは、1週間に体重の 0.75% までにしています。1日の目安は 1,200 kcal より下げません。"
                )
            }
        }

        @Suite("見送った週")
        struct Deferred {
            static func guide(_ reason: WeeklyReview.DeferralReason, meals: [MealCard] = [])
                throws -> WeekRecap.NextWeekGuide
            {
                let goal = try Goal.losing()
                return try #require(
                    try NextWeekGuide.recap(
                        goal: goal,
                        outcome: { _, _ in .deferred(reason: reason, goalId: goal.id) },
                        newGuideArrived: false, meals: meals
                    ).nextWeekGuide)
            }

            @Test("前の週の1日の目安のまま、そのままと出すこと")
            func keepsGuide() throws {
                let guide = try Self.guide(.noWeight)

                #expect(guide.energyKilocalories == 1880)
                #expect(guide.changeText == "そのまま")
            }

            @Test("食事の記録が少なければ、記録した日数を理由にすること")
            func explainsFewMealRecords() throws {
                let meals = try ["12", "14", "16"].map { day in
                    try MealCard.fixture(
                        eatenAt: "2026-10-\(day)T12:00:00+09:00", status: .estimated,
                        nutrients: [.energyKcal: 1800])
                }

                #expect(
                    try Self.guide(.fewMealRecords, meals: meals).sentence
                        == "1,880 kcal のままです。食事の記録が 3 日だったためです。")
            }

            @Test("体重が無ければ、体重の記録が無かったことを理由にすること")
            func explainsNoWeight() throws {
                #expect(
                    try Self.guide(.noWeight).sentence == "1,880 kcal のままです。体重の記録が無かったためです。")
            }

            @Test("使い始めて7日たっていなければ、そのことを理由にすること")
            func explainsFirstWeek() throws {
                #expect(
                    try Self.guide(.withinFirstWeek).sentence
                        == "1,880 kcal のままです。使い始めて7日たっていないためです。")
            }
        }

        @Suite("出さないとき")
        struct NotShown {
            @Test("今週は出さないこと")
            func notInProgress() throws {
                let recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 18)))

                #expect(recap.nextWeekGuide == nil)
            }

            @Test("新しい1日の目安がまだ届いていなければ出さないこと")
            func waitsForGuide() throws {
                let recap = try NextWeekGuide.recap(
                    outcome: NextWeekGuide.reviewed(.expenditureChange), newGuideArrived: false)

                #expect(recap.nextWeekGuide == nil)
            }

            @Test("月曜に立て直して、見直した1日の目安が1日も当たらなければ出さないこと")
            func skipsUnusedGuide() throws {
                let nextId = UUID()
                let recap = try NextWeekGuide.recap(
                    goal: try NextWeekGuide.losingClosed(nextGoalId: nextId, endReason: .switched),
                    outcome: NextWeekGuide.reviewed(.expenditureChange),
                    extraGoals: [try NextWeekGuide.maintainingFromMonday(id: nextId)])

                #expect(recap.nextWeekGuide == nil)
            }
        }
    }
}
