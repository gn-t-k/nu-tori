#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// 見本の人の値。出どころは `UITestLaunch.listingSampleScenario()` のコメント
    private struct ListingSample {
        let timeZone: TimeZone

        static let goalStartedOn = "2026-01-05"
        /// `person.targetWeightKg`
        static let targetWeightKilograms = 74.4
        /// `initial.startingWeightTrendKg`
        static let startingWeightTrendKilograms = 78.3804
        /// `person.daysFromStartToDeadline` 日後
        static let deadlineOn = "2026-03-30"

        /// 推定消費カロリーと1日の目安が変わった週。1つめは目標を立てたとき（`initial`）、2つめからは `reviews` の見直し
        struct Week {
            let effectiveOn: String
            let expenditureKilocalories: Int
            let guide: (energy: Int, protein: Int, fat: Int, carbohydrate: Int)
            let limitHits: [SyncedDailyGuide.LimitHit]
            /// 目標を立てたときは nil。理由はサーバーの `computeMainReason` で出した向き
            let mainReason: SyncedWeeklyReview.MainReason?
        }

        static let weeks = [
            Week(
                effectiveOn: "2026-01-05", expenditureKilocalories: 2399,
                guide: (2050, 120, 55, 270), limitHits: [], mainReason: nil),
            Week(
                effectiveOn: "2026-01-12", expenditureKilocalories: 2287,
                guide: (1900, 120, 55, 230), limitHits: [.weeklyChange],
                mainReason: .expenditureChange),
            Week(
                effectiveOn: "2026-01-19", expenditureKilocalories: 2154,
                guide: (1750, 120, 50, 205), limitHits: [.weeklyChange],
                mainReason: .expenditureChange),
        ]

        /// 毎朝 7:00 に量った体重と、その日の体重の傾向（`days` の `weightKg`・`trendKg`）
        struct Day {
            let calendarDay: String
            let kilograms: Double
            let trendKilograms: Double
        }

        static let days = [
            Day(calendarDay: "2026-01-05", kilograms: 78.1, trendKilograms: 78.3524),
            Day(calendarDay: "2026-01-06", kilograms: 78.5, trendKilograms: 78.3671),
            Day(calendarDay: "2026-01-07", kilograms: 78.9, trendKilograms: 78.4204),
            Day(calendarDay: "2026-01-08", kilograms: 78.8, trendKilograms: 78.4584),
            Day(calendarDay: "2026-01-09", kilograms: 78.4, trendKilograms: 78.4525),
            Day(calendarDay: "2026-01-10", kilograms: 78.7, trendKilograms: 78.4773),
            Day(calendarDay: "2026-01-11", kilograms: 78.4, trendKilograms: 78.4696),
            Day(calendarDay: "2026-01-12", kilograms: 78.7, trendKilograms: 78.4926),
            Day(calendarDay: "2026-01-13", kilograms: 78.3, trendKilograms: 78.4733),
            Day(calendarDay: "2026-01-14", kilograms: 78.0, trendKilograms: 78.4260),
            Day(calendarDay: "2026-01-15", kilograms: 78.4, trendKilograms: 78.4234),
            Day(calendarDay: "2026-01-16", kilograms: 78.5, trendKilograms: 78.4311),
            Day(calendarDay: "2026-01-17", kilograms: 78.0, trendKilograms: 78.3880),
            Day(calendarDay: "2026-01-18", kilograms: 78.1, trendKilograms: 78.3592),
            Day(calendarDay: "2026-01-19", kilograms: 77.7, trendKilograms: 78.2932),
            Day(calendarDay: "2026-01-20", kilograms: 77.7, trendKilograms: 78.2339),
            Day(calendarDay: "2026-01-21", kilograms: 77.8, trendKilograms: 78.1905),
        ]

        var goal: SyncedGoal {
            SyncedGoal(
                id: Self.goalId, startedOn: Self.goalStartedOn,
                startingWeightTrendKilograms: Self.startingWeightTrendKilograms,
                targetWeightKilograms: Self.targetWeightKilograms,
                decidedAt: date(Self.goalStartedOn, hour: 7, minute: 10), timeZone: timeZone,
                direction: .lose(.init(deadlineOn: Self.deadlineOn, pacePlan: .custom)),
                achievement: nil, deadlineConfirmation: nil, closure: nil)
        }

        /// その週の推定消費カロリーと1日の目安。見直しの週には、月曜の 0:05 の見直しを添える
        func records(of week: Week, at index: Int) -> [SyncChange] {
            let estimateId = Self.id(0x71, index)
            let guideId = Self.id(0x72, index)
            let estimatedAt =
                week.mainReason == nil
                ? date(week.effectiveOn, hour: 7, minute: 10)
                : date(week.effectiveOn, hour: 0, minute: 5)
            let estimate = SyncChange.expenditureEstimate(
                SyncedExpenditureEstimate(
                    id: estimateId, effectiveOn: week.effectiveOn,
                    expenditureKilocalories: week.expenditureKilocalories,
                    estimatedAt: estimatedAt,
                    initialSource: week.mainReason == nil ? .formula : nil))
            let guide = SyncChange.dailyGuide(
                SyncedDailyGuide(
                    id: guideId, goalId: Self.goalId, expenditureEstimateId: estimateId,
                    effectiveOn: week.effectiveOn, energyKilocalories: week.guide.energy,
                    proteinGrams: week.guide.protein, fatGrams: week.guide.fat,
                    carbohydrateGrams: week.guide.carbohydrate, limitHits: week.limitHits))
            guard let mainReason = week.mainReason else { return [estimate, guide] }
            return [
                estimate, guide,
                .weeklyReview(
                    SyncedWeeklyReview(
                        id: Self.id(0x73, index), effectiveOn: week.effectiveOn,
                        reviewedAt: estimatedAt, timeZone: timeZone,
                        outcome: .reviewed(
                            expenditureEstimateId: estimateId, dailyGuideId: guideId,
                            mainReason: mainReason))),
            ]
        }

        /// 手で記録した朝の体重
        func weight(of day: Day, at index: Int) -> SyncChange {
            .weightRecord(
                SyncedWeightRecord(
                    id: Self.id(0x74, index), weightKilograms: day.kilograms,
                    measuredAt: date(day.calendarDay, hour: 7, minute: 0), timeZone: timeZone,
                    version: 1, imported: nil))
        }

        func day(_ text: String) -> CalendarDay {
            guard let day = CalendarDay(yearMonthDay: text) else {
                preconditionFailure("YYYY-MM-DD の形でない \(text)")
            }
            return day
        }

        private func date(_ text: String, hour: Int, minute: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let day = day(text)
            guard
                let date = calendar.date(
                    from: DateComponents(
                        year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))
            else {
                preconditionFailure("\(text) の \(hour):\(minute) を作れない")
            }
            return date
        }

        private static let goalId = id(0x70, 0)

        /// 種類ごとの印と並びの番号から、決まった ID を作る
        private static func id(_ kind: Int, _ index: Int) -> UUID {
            let text = String(format: "%08x-0000-4000-8000-%012d", kind, index)
            guard let id = UUID(uuidString: text) else {
                preconditionFailure("UUID の形でない \(text)")
            }
            return id
        }
    }

    extension UITestLaunch {
        /// 掲載情報と LP の手順の絵を撮る見本の場面（UI テストの `ListingScene`）の記録。作り物で、開発者の健康データは使わない（ADR-0010）。
        ///
        /// 見本の人は、出し方のページの「Aさんの例」とそろえる。
        /// 体重・体重の傾向・推定消費カロリー・1日の目安・見直しの値は `site/src/pages/daily-guide/daily-guide-example.json`（`server/scripts/print-daily-guide-example.ts` がサーバーのドメイン層の関数で書き出す）の `initial`・`days`・`reviews` から写し、P・F・C はサーバーの `computeMacronutrientGuides`（目標体重 74.4 kg）で出した値にする。
        /// 例の筋が変わって JSON を書き出し直したら、ここも写し直す。
        ///
        /// 1月5日（月）に、体重の傾向 78.4 kg から 12 週で 74.4 kg へ減らす目標を立て、毎週月曜の 0:05 に見直した。
        /// 今日（止めた時計の日）より後の記録は置かない。写真の食事の推定は、時刻を直すまで終えない（推定を待つカードを撮るため）
        func listingSampleScenario() -> FakeSyncServer.Scenario {
            let today = clock.today()
            let sample = ListingSample(timeZone: clock.timeZone())
            let weeks = ListingSample.weeks.filter { sample.day($0.effectiveOn) <= today }
            let days = ListingSample.days.filter { sample.day($0.calendarDay) <= today }
            return .init(
                records: [.goal(sample.goal)]
                    + weeks.enumerated().flatMap { index, week in
                        sample.records(of: week, at: index)
                    }
                    + days.enumerated().map { index, day in sample.weight(of: day, at: index) }
                    + [
                        .weightTrend(
                            SyncedWeightTrend(
                                days: days.map {
                                    .init(
                                        calendarDay: $0.calendarDay,
                                        trendKilograms: $0.trendKilograms)
                                }))
                    ],
                startedOn: ListingSample.goalStartedOn,
                mealEstimation: .afterEatenAtCorrected)
        }
    }
#endif
