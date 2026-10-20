import Foundation
import NuToriCore
import Testing

extension WeekRecapTests {
    @Suite("1週目の見直しに使った記録")
    struct FirstWeekNote {
        @Suite("1週目")
        struct FirstWeek {
            let recap: WeekRecap

            init() throws {
                recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 1), today: WeekRecapTests.day(10, 10)))
            }

            @Test("立てた日より前を含めた月〜日を見直しに使ったと添えること")
            func notesReviewedWeek() {
                #expect(recap.firstWeekNote == "1日の目安の見直しには、9月28日〜10月4日の 7 日の記録を使っています。")
            }
        }

        @Suite("2週目から")
        struct LaterWeek {
            let recap: WeekRecap

            init() throws {
                recap = try #require(
                    try WeekRecapTests.recap(
                        weekOf: WeekRecapTests.day(10, 5), today: WeekRecapTests.day(10, 13)))
            }

            @Test("添えないこと")
            func hasNoNote() {
                #expect(recap.firstWeekNote == nil)
            }
        }
    }

    @Suite("次の週の1日の目安")
    struct NextWeekGuide {
        /// 10月12日〜18日の週と、10月19日から当てる見直し。前の1日の目安は既定で 1,880 kcal（推定消費カロリー 2,190 kcal）
        static func recap(
            goal: Goal? = nil, previousGuideKilocalories: Int = 1880,
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
                effectiveDay: WeekRecapTests.day(10, 1),
                energyKilocalories: previousGuideKilocalories,
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

        /// 10月1日に始めた、12月24日までに 60.0 kg から 64.0 kg へ増やす目標
        static func gaining() throws -> Goal {
            Goal(
                id: UUID(), startedDay: WeekRecapTests.day(10, 1),
                startingWeightTrendKilograms: 60.0, targetWeightKilograms: 64.0,
                decidedAt: try Date("2026-10-01T08:30:00+09:00", strategy: .iso8601),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                direction: .gain(
                    Goal.WeightChange(deadlineDay: WeekRecapTests.day(12, 24), pacePlan: .standard)),
                achievement: nil, deadlineConfirmation: nil, closure: nil)
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

        @Suite("1日の目安と推定消費カロリーの差の変化で変わったとき")
        struct BalanceChange {
            @Suite("1日の目安を推定消費カロリーからさらに下げたなら")
            struct Increased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    // 推定消費カロリー 2,190 → 2,140、1日の目安と推定消費カロリーの差 310 → 390 kcal
                    guide = try #require(
                        try NextWeekGuide.recap(
                            outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 1750
                        ).nextWeekGuide)
                }

                @Test("期限に間に合うよう目安を推定消費カロリーより下げたことを理由にすること")
                func explainsBalance() {
                    #expect(
                        guide.sentence
                            == "1,880 → 1,750 kcal。期限に間に合うよう、1日の目安を推定消費カロリーよりさらに下げたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("1日の目安を推定消費カロリーに近づけたなら")
            struct Decreased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    guide = try #require(
                        try NextWeekGuide.recap(
                            outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 1900
                        ).nextWeekGuide)
                }

                @Test("体重が予定より早く減っていることを理由にすること")
                func explainsBalanceDecrease() {
                    #expect(
                        guide.sentence
                            == "1,880 → 1,900 kcal。体重が予定より早く減っているので、1日の目安を推定消費カロリーに近づけたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("増量で1日の目安を推定消費カロリーからさらに上げたなら")
            struct GainIncreased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    // 前の週は推定消費カロリー 2,190 kcal に 210 kcal 足した 2,400 kcal
                    guide = try #require(
                        try NextWeekGuide.recap(
                            goal: NextWeekGuide.gaining(), previousGuideKilocalories: 2400,
                            outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 2500
                        ).nextWeekGuide)
                }

                @Test("期限に間に合うよう目安を推定消費カロリーより上げたことを理由にすること")
                func explainsGainIncrease() {
                    #expect(
                        guide.sentence
                            == "2,400 → 2,500 kcal。期限に間に合うよう、1日の目安を推定消費カロリーよりさらに上げたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("増量で1日の目安を推定消費カロリーに近づけたなら")
            struct GainDecreased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    // 前の週は推定消費カロリー 2,190 kcal に 210 kcal 足した 2,400 kcal
                    guide = try #require(
                        try NextWeekGuide.recap(
                            goal: NextWeekGuide.gaining(), previousGuideKilocalories: 2400,
                            outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 2250
                        ).nextWeekGuide)
                }

                @Test("体重が予定より早く増えていることを理由にすること")
                func explainsGainDecrease() {
                    #expect(
                        guide.sentence
                            == "2,400 → 2,250 kcal。体重が予定より早く増えているので、1日の目安を推定消費カロリーに近づけたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("維持で1日の目安を推定消費カロリーより下げたなら")
            struct MaintenanceIncreased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    let maintaining = try Goal.maintaining(
                        startedOn: WeekRecapTests.day(10, 1), kilograms: 72.4,
                        decidedAt: "2026-10-01T08:30:00+09:00")
                    guide = try #require(
                        try NextWeekGuide.recap(
                            goal: maintaining, outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 1800
                        ).nextWeekGuide)
                }

                @Test("体重の傾向が目標体重を上回っていることを理由にすること")
                func explainsMaintenanceBalance() {
                    #expect(
                        guide.sentence
                            == "1,880 → 1,800 kcal。体重の傾向が 72.4 kg を上回っているので、1日の目安を推定消費カロリーより下げたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("維持で1日の目安を推定消費カロリーより上げたなら")
            struct MaintenanceRaised {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    let maintaining = try Goal.maintaining(
                        startedOn: WeekRecapTests.day(10, 1), kilograms: 72.4,
                        decidedAt: "2026-10-01T08:30:00+09:00")
                    guide = try #require(
                        try NextWeekGuide.recap(
                            goal: maintaining, outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 2500
                        ).nextWeekGuide)
                }

                @Test("体重の傾向が目標体重を下回っていることを理由にすること")
                func explainsMaintenanceRaise() {
                    #expect(
                        guide.sentence
                            == "1,880 → 2,500 kcal。体重の傾向が 72.4 kg を下回っているので、1日の目安を推定消費カロリーより上げたためです。推移は目標で見られます。"
                    )
                }
            }

            @Suite("維持で1日の目安を推定消費カロリーに近づけたなら")
            struct MaintenanceEased {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    let maintaining = try Goal.maintaining(
                        startedOn: WeekRecapTests.day(10, 1), kilograms: 72.4,
                        decidedAt: "2026-10-01T08:30:00+09:00")
                    guide = try #require(
                        try NextWeekGuide.recap(
                            goal: maintaining, outcome: NextWeekGuide.reviewed(.balanceChange),
                            newGuideKilocalories: 2000
                        ).nextWeekGuide)
                }

                @Test("体重の傾向が目標体重に近づいたことを理由にすること")
                func explainsMaintenanceEase() {
                    #expect(
                        guide.sentence
                            == "1,880 → 2,000 kcal。体重の傾向が 72.4 kg に近づいたので、1日の目安を推定消費カロリーに近づけたためです。推移は目標で見られます。"
                    )
                }
            }
        }

        @Suite("達成したあとに変わったとき")
        struct AfterAchievement {
            let guide: WeekRecap.NextWeekGuide

            init() throws {
                let goal = try Goal.losing(
                    achievement: .inTokyo(
                        on: WeekRecapTests.day(10, 15), judgedAt: "2026-10-15T07:10:00+09:00"))
                guide = try #require(
                    try NextWeekGuide.recap(
                        goal: goal, outcome: NextWeekGuide.reviewed(.balanceChange),
                        newGuideKilocalories: 2000
                    ).nextWeekGuide)
            }

            @Test("減らす分をなくしていくことを理由にすること")
            func explainsAchievement() {
                #expect(
                    guide.sentence
                        == "1,880 → 2,000 kcal。目標に届いたので、1日の目安を推定消費カロリーに近づけていくためです。推移は目標で見られます。")
            }
        }

        @Suite("期限後の維持に移ったとき")
        struct MovedToMaintenance {
            let guide: WeekRecap.NextWeekGuide

            init() throws {
                let maintenanceId = UUID()
                guide = try #require(
                    try NextWeekGuide.recap(
                        goal: try NextWeekGuide.losingClosed(
                            nextGoalId: maintenanceId, endReason: .movedToMaintenance),
                        outcome: NextWeekGuide.reviewed(.balanceChange),
                        newGuideKilocalories: 2000, newGuideGoalId: maintenanceId,
                        extraGoals: [try NextWeekGuide.maintainingFromMonday(id: maintenanceId)]
                    ).nextWeekGuide)
            }

            @Test("今の体重を保つ目標に切り替えたことを理由にすること")
            func explainsMaintenance() {
                #expect(
                    guide.sentence
                        == "1,880 → 2,000 kcal。今の体重を保つ目標に切り替えたためです。推移は目標で見られます。")
            }
        }

        @Suite("上限と下限に当たったとき")
        struct LimitHits {
            let guide: WeekRecap.NextWeekGuide

            init() throws {
                guide = try #require(
                    try NextWeekGuide.recap(
                        outcome: NextWeekGuide.reviewed(.expenditureChange),
                        limitHits: [.weeklyChange, .requiredPace, .minimumEnergy]
                    ).nextWeekGuide)
            }

            @Test("当たった決まりを1つずつ文で足すこと")
            func explainsLimits() {
                #expect(
                    guide.sentence
                        == "1,880 → 1,850 kcal。推定消費カロリーが 2,190 から 2,140 kcal に下がったためです。推移は目標で見られます。1日の目安を1週間に変えるのは 150 kcal までにしています。1週間に減らすのは、体重の 0.75% までにしています。1日の目安は 1,200 kcal より下げません。"
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

            @Suite("体重が無くて見送ったなら")
            struct NoWeight {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    guide = try Deferred.guide(.noWeight)
                }

                @Test("前の週の1日の目安のまま、そのままと出すこと")
                func keepsGuide() {
                    #expect(guide.energyKilocalories == 1880)
                    #expect(guide.changeText == "そのまま")
                }

                @Test("体重の記録が無かったことを理由にすること")
                func explainsNoWeight() {
                    #expect(guide.sentence == "1,880 kcal のままです。体重の記録が無かったためです。")
                }
            }

            @Suite("食事の記録が少なくて見送ったなら")
            struct FewMealRecords {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    let meals = try ["12", "14", "16"].map { day in
                        try MealCard.fixture(
                            eatenAt: "2026-10-\(day)T12:00:00+09:00", status: .estimated,
                            nutrients: [.energyKcal: 1800])
                    }
                    guide = try Deferred.guide(.fewMealRecords, meals: meals)
                }

                @Test("記録した日数を理由にすること")
                func explainsFewMealRecords() {
                    #expect(guide.sentence == "1,880 kcal のままです。食事の記録が 3 日だったためです。")
                }
            }

            @Suite("使い始めて7日たっていなくて見送ったなら")
            struct WithinFirstWeek {
                let guide: WeekRecap.NextWeekGuide

                init() throws {
                    guide = try Deferred.guide(.withinFirstWeek)
                }

                @Test("そのことを理由にすること")
                func explainsFirstWeek() {
                    #expect(guide.sentence == "1,880 kcal のままです。使い始めて7日たっていないためです。")
                }
            }
        }

        @Suite("出さないとき")
        struct NotShown {
            @Suite("今週なら")
            struct InProgress {
                let recap: WeekRecap

                init() throws {
                    recap = try #require(
                        try WeekRecapTests.recap(
                            weekOf: WeekRecapTests.day(10, 12), today: WeekRecapTests.day(10, 18)))
                }

                @Test("出さないこと")
                func hasNoGuide() {
                    #expect(recap.nextWeekGuide == nil)
                }
            }

            @Suite("新しい1日の目安がまだ届いていなければ")
            struct GuideNotArrived {
                let recap: WeekRecap

                init() throws {
                    recap = try NextWeekGuide.recap(
                        outcome: NextWeekGuide.reviewed(.expenditureChange), newGuideArrived: false)
                }

                @Test("出さないこと")
                func waitsForGuide() {
                    #expect(recap.nextWeekGuide == nil)
                }
            }

            @Suite("月曜に立て直して、見直した1日の目安が1日も当たらなければ")
            struct UnusedGuide {
                let recap: WeekRecap

                init() throws {
                    let nextId = UUID()
                    recap = try NextWeekGuide.recap(
                        goal: try NextWeekGuide.losingClosed(
                            nextGoalId: nextId, endReason: .switched),
                        outcome: NextWeekGuide.reviewed(.expenditureChange),
                        extraGoals: [try NextWeekGuide.maintainingFromMonday(id: nextId)])
                }

                @Test("出さないこと")
                func skipsUnusedGuide() {
                    #expect(recap.nextWeekGuide == nil)
                }
            }
        }
    }
}
