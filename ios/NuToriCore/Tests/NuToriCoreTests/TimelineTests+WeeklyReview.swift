import Foundation
import NuToriCore
import Testing

extension TimelineTests {
    /// 2026-10-01（木）に始めた、12月24日までに 72.4 kg から 68.0 kg へ減らす目標（`Goal.losing()`）の週の見直し。
    /// 始めの推定消費カロリーは 2,190 kcal、1日の目安は 1,880 kcal
    @Suite("週の見直し")
    struct PlacingWeeklyReview {
        @Suite("1週を見直したとき")
        struct OneWeekReviewed {
            let scene: WeeklyReviewScene
            let review: WeeklyReview
            let before: WeightRecord
            let after: WeightRecord
            let recordedDay: WeightRecord
            let timeline: Timeline

            init() throws {
                scene = try WeeklyReviewScene()
                review = try scene.reviewed(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                    reviewedAt: "2026-10-05T06:10:00+09:00", guide: scene.reviewedGuide,
                    estimate: scene.reviewedEstimate, mainReason: .expenditureChange)
                before = try .manual(72.1, at: "2026-10-05T06:00:00+09:00", in: "Asia/Tokyo")
                after = try .manual(72.0, at: "2026-10-05T07:00:00+09:00", in: "Asia/Tokyo")
                recordedDay = try .manual(72.2, at: "2026-10-03T07:00:00+09:00", in: "Asia/Tokyo")
                timeline = scene.timeline(
                    reviews: [review], weightRecords: [recordedDay, before, after],
                    today: CalendarDay(year: 2026, month: 10, day: 5))
            }

            @Test("見直した時刻の位置に振り返りのカードを置き、すぐ下に変更の知らせを置くこと")
            func placesCardAndNoticeAtReviewedTime() {
                #expect(
                    WeeklyReviewScene.itemIds(
                        on: CalendarDay(year: 2026, month: 10, day: 5), in: timeline) == [
                            "record-\(before.id.uuidString)",
                            "weekly-review-\(review.id.uuidString)",
                            "daily-guide-change-\(review.id.uuidString)",
                            "record-\(after.id.uuidString)",
                        ])
            }

            @Test("アプリからの知らせとして、自分の記録と間を空けること")
            func isSpokenByApp() throws {
                let day = try #require(timeline.days.first { $0.day.day == 5 })
                #expect(day.items.filter { $0.speaker == .app }.count == 2)
            }

            @Test("カードの週は、1週目なので目標の開始の日から日曜までにすること")
            func cardWeekStartsAtGoalStart() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(
                    card.days
                        == CalendarDay(
                            year: 2026, month: 10, day: 1)...CalendarDay(
                            year: 2026, month: 10, day: 4))
            }

            @Test("7日の丸は月〜日に並べ、その週に当たっていた1日の目安と比べること")
            func ringsCompareWithGuideOfTheWeek() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                let guide = scene.initialGuide
                #expect(
                    card.rings == [
                        .beforeFirstDay(CalendarDay(year: 2026, month: 9, day: 28)),
                        .beforeFirstDay(CalendarDay(year: 2026, month: 9, day: 29)),
                        .beforeFirstDay(CalendarDay(year: 2026, month: 9, day: 30)),
                        .ring(
                            CalendarDay(year: 2026, month: 10, day: 1),
                            DayRing(hasWeightRecord: false, food: .noMeals, dailyGuide: guide)),
                        .ring(
                            CalendarDay(year: 2026, month: 10, day: 2),
                            DayRing(hasWeightRecord: false, food: .noMeals, dailyGuide: guide)),
                        .ring(
                            CalendarDay(year: 2026, month: 10, day: 3),
                            DayRing(hasWeightRecord: true, food: .noMeals, dailyGuide: guide)),
                        .ring(
                            CalendarDay(year: 2026, month: 10, day: 4),
                            DayRing(hasWeightRecord: false, food: .noMeals, dailyGuide: guide)),
                    ])
            }

            @Test("ペースの1行は、目標を立てて 14 日たっていないことを言うこと")
            func paceLineSaysPending() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.paceText == "ペースは目標を立てて 14 日たつと出ます")
            }

            @Test("カードに見送りとまとめた週の文を出さないこと")
            func cardHasNoDeferralOrBatchText() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.deferralText == nil)
                #expect(card.batchText == nil)
            }

            @Test("変更の知らせは、新しい1日の目安と変わった量を持つこと")
            func noticeHasNewGuideAndChange() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.dailyGuide == scene.reviewedGuide)
                #expect(notice.changeKilocalories == -30)
            }

            @Test("変更の知らせの理由は、推定消費カロリーが下がったことを言うこと")
            func noticeSaysExpenditureDecreased() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.reasonText == "推定消費カロリーが 2,190 から 2,140 kcal に下がったためです。")
                #expect(notice.batchText == nil)
            }

            @Test("帯の下の1行に出さないこと")
            func isNotInUnansweredLines() {
                #expect(timeline.unansweredNoticeLines.isEmpty)
            }
        }

        @Suite("見送った週")
        struct Deferred {
            let review: WeeklyReview
            let timeline: Timeline

            init() throws {
                let scene = try WeeklyReviewScene()
                review = try scene.deferred(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                    reviewedAt: "2026-10-05T06:10:00+09:00")
                timeline = scene.timeline(
                    reviews: [review], weightRecords: [],
                    today: CalendarDay(year: 2026, month: 10, day: 5))
            }

            @Test("振り返りのカードだけを置き、変更の知らせを置かないこと")
            func placesOnlyCard() {
                #expect(
                    WeeklyReviewScene.itemIds(
                        on: CalendarDay(year: 2026, month: 10, day: 5), in: timeline) == [
                            "weekly-review-\(review.id.uuidString)"
                        ])
            }

            @Test("カードに1日の目安がそのままであることを出すこと")
            func cardSaysGuideUnchanged() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.deferralText == "1日の目安はそのままです。")
            }
        }

        @Suite("同じ時刻に3週をまとめて見直したとき")
        struct Batched {
            let latest: WeeklyReview
            let timeline: Timeline

            init() throws {
                let scene = try WeeklyReviewScene()
                let middleEstimate = scene.estimate(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 12), kilocalories: 2120)
                let middleGuide = scene.guide(
                    estimate: middleEstimate,
                    effectiveOn: CalendarDay(
                        year: 2026, month: 10, day: 12), kilocalories: 1840)
                let latestEstimate = scene.estimate(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 19), kilocalories: 2100)
                let latestGuide = scene.guide(
                    estimate: latestEstimate,
                    effectiveOn: CalendarDay(
                        year: 2026, month: 10, day: 19), kilocalories: 1820)
                let reviewedAt = "2026-10-19T07:00:00+09:00"
                latest = try scene.reviewed(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 19),
                    reviewedAt: reviewedAt, guide: latestGuide, estimate: latestEstimate,
                    mainReason: .balanceChange)
                timeline = scene.timeline(
                    reviews: [
                        try scene.reviewed(
                            effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                            reviewedAt: reviewedAt, guide: scene.reviewedGuide,
                            estimate: scene.reviewedEstimate, mainReason: .expenditureChange),
                        try scene.reviewed(
                            effectiveOn: CalendarDay(year: 2026, month: 10, day: 12),
                            reviewedAt: reviewedAt, guide: middleGuide, estimate: middleEstimate,
                            mainReason: .expenditureChange),
                        latest,
                    ],
                    extraEstimates: [middleEstimate, latestEstimate],
                    extraGuides: [middleGuide, latestGuide],
                    weightRecords: [], today: CalendarDay(year: 2026, month: 10, day: 19))
            }

            @Test("いちばん新しい週のカードと変更の知らせを1組だけ置くこと")
            func placesOnlyLatestPair() {
                #expect(
                    timeline.days.flatMap(\.items).map(\.id) == [
                        "weekly-review-\(latest.id.uuidString)",
                        "daily-guide-change-\(latest.id.uuidString)",
                    ])
            }

            @Test("カードに、ほかに見直した週の数を出すこと")
            func cardSaysOtherWeeks() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.batchText == "ほかに 2 週を見直しました。‹ で前の週へ送れます。")
            }

            @Test("変わった量は、まとめた最初の週の前の1日の目安と比べること")
            func changeComparesWithGuideBeforeFirstWeek() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.changeKilocalories == -60)
            }

            @Test("理由は、まとめた最初の週の前と比べて大きく変わったほうにすること")
            func reasonComparesWithBeforeFirstWeek() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.reasonText == "推定消費カロリーが 2,190 から 2,100 kcal に下がったためです。")
            }

            @Test("変更の知らせに、まとめた週の始まりと数を出すこと")
            func noticeSaysBatch() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.batchText == "9月28日からの 3 週分の見直しをまとめた値です。")
            }
        }

        @Suite("まとめて見直したいちばん新しい週が見送りのとき")
        struct BatchedEndingWithDeferral {
            let scene: WeeklyReviewScene
            let timeline: Timeline

            init() throws {
                scene = try WeeklyReviewScene()
                let reviewedAt = "2026-10-12T07:00:00+09:00"
                timeline = scene.timeline(
                    reviews: [
                        try scene.reviewed(
                            effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                            reviewedAt: reviewedAt, guide: scene.reviewedGuide,
                            estimate: scene.reviewedEstimate, mainReason: .expenditureChange),
                        try scene.deferred(
                            effectiveOn: CalendarDay(year: 2026, month: 10, day: 12),
                            reviewedAt: reviewedAt),
                    ],
                    weightRecords: [], today: CalendarDay(year: 2026, month: 10, day: 12))
            }

            @Test("前の週までの変化を変更の知らせに出すこと")
            func noticeShowsChangeUntilPreviousWeek() throws {
                let notice = try #require(WeeklyReviewScene.changeNotice(in: timeline))
                #expect(notice.dailyGuide == scene.reviewedGuide)
                #expect(notice.changeKilocalories == -30)
            }

            @Test("カードに1日の目安がそのままであることを出すこと")
            func cardSaysGuideUnchanged() throws {
                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.deferralText == "1日の目安はそのままです。")
            }
        }

        @Suite("指す1日の目安がまだ届いていないとき")
        struct GuideNotArrived {
            let review: WeeklyReview
            let timeline: Timeline

            init() throws {
                let scene = try WeeklyReviewScene()
                review = try scene.reviewed(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                    reviewedAt: "2026-10-05T06:10:00+09:00", guide: scene.reviewedGuide,
                    estimate: scene.reviewedEstimate, mainReason: .expenditureChange)
                timeline = scene.timeline(
                    reviews: [review], includesReviewedGuide: false, weightRecords: [],
                    today: CalendarDay(year: 2026, month: 10, day: 5))
            }

            @Test("振り返りのカードだけを置き、変更の知らせを描かないこと")
            func placesOnlyCard() {
                #expect(
                    WeeklyReviewScene.itemIds(
                        on: CalendarDay(year: 2026, month: 10, day: 5), in: timeline) == [
                            "weekly-review-\(review.id.uuidString)"
                        ])
            }
        }

        @Suite("月曜に立て直した週の、前の目標に書いた1日の目安")
        struct GoalSwitchedOnMonday {
            let review: WeeklyReview
            let timeline: Timeline

            init() throws {
                let scene = try WeeklyReviewScene()
                let monday = CalendarDay(year: 2026, month: 10, day: 5)
                let next = try Goal.maintaining(id: UUID())
                let switched = Goal(
                    id: scene.goal.id, startedDay: scene.goal.startedDay,
                    startingWeightTrendKilograms: scene.goal.startingWeightTrendKilograms,
                    targetWeightKilograms: scene.goal.targetWeightKilograms,
                    decidedAt: scene.goal.decidedAt, timeZone: scene.goal.timeZone,
                    direction: scene.goal.direction, achievement: nil, deadlineConfirmation: nil,
                    closure: Goal.Closure(
                        endedDay: monday, nextGoalId: next.id, endReason: .switched)
                )
                review = try scene.reviewed(
                    effectiveOn: monday, reviewedAt: "2026-10-05T06:10:00+09:00",
                    guide: scene.reviewedGuide, estimate: scene.reviewedEstimate,
                    mainReason: .expenditureChange)
                timeline = scene.timeline(
                    reviews: [review], goals: [switched, next], weightRecords: [], today: monday)
            }

            @Test("振り返りのカードだけを置き、変更の知らせを出さないこと")
            func placesOnlyCard() {
                #expect(
                    WeeklyReviewScene.itemIds(
                        on: CalendarDay(year: 2026, month: 10, day: 5), in: timeline) == [
                            "weekly-review-\(review.id.uuidString)"
                        ])
            }
        }

        @Suite("変更の知らせの理由")
        struct ChangeReason {
            static let monday = CalendarDay(year: 2026, month: 10, day: 5)

            /// 10月5日に見直して、推定消費カロリーを `kilocalories`、1日の目安を `guideKilocalories` にした知らせ
            static func notice(
                scene: WeeklyReviewScene, goals: [Goal]? = nil, guideGoalId: UUID? = nil,
                kilocalories: Int, guideKilocalories: Int, mainReason: WeeklyReview.MainReason
            ) throws -> DailyGuideChangeNotice? {
                let estimate = scene.estimate(effectiveOn: monday, kilocalories: kilocalories)
                let guide = scene.guide(
                    estimate: estimate, effectiveOn: monday, kilocalories: guideKilocalories,
                    goalId: guideGoalId)
                let timeline = scene.timeline(
                    reviews: [
                        try scene.reviewed(
                            effectiveOn: monday, reviewedAt: "2026-10-05T06:10:00+09:00",
                            guide: guide, estimate: estimate, mainReason: mainReason)
                    ],
                    goals: goals, extraEstimates: [estimate], extraGuides: [guide],
                    weightRecords: [], today: monday)
                return WeeklyReviewScene.changeNotice(in: timeline)
            }

            @Test("推定消費カロリーが上がったときは、上がったことを言うこと")
            func expenditureIncreased() throws {
                let notice = try #require(
                    try Self.notice(
                        scene: try WeeklyReviewScene(), kilocalories: 2230,
                        guideKilocalories: 1920, mainReason: .expenditureChange))
                #expect(notice.reasonText == "推定消費カロリーが 2,190 から 2,230 kcal に上がったためです。")
                #expect(notice.changeText == "+40 kcal")
            }

            @Test("1日に減らす分を増やしたときは、期限までの日が減ったことを言うこと")
            func balanceIncreased() throws {
                let notice = try #require(
                    try Self.notice(
                        scene: try WeeklyReviewScene(), kilocalories: 2190,
                        guideKilocalories: 1850, mainReason: .balanceChange))
                #expect(notice.reasonText == "期限までの日が減り、1日に減らす分を増やしたためです。")
            }

            @Test("達成したあとは、1日に減らす分をなくしていくことを言うこと")
            func afterAchievement() throws {
                let losing = try Goal.losing()
                let achieved = Goal(
                    id: losing.id, startedDay: losing.startedDay,
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction,
                    achievement: Goal.Achievement(
                        achievedDay: CalendarDay(year: 2026, month: 10, day: 3),
                        judgedAt: try Date("2026-10-03T07:30:00+09:00", strategy: .iso8601),
                        timeZone: losing.timeZone),
                    deadlineConfirmation: nil, closure: nil)
                let notice = try #require(
                    try Self.notice(
                        scene: try WeeklyReviewScene(goal: achieved), kilocalories: 2190,
                        guideKilocalories: 1990, mainReason: .balanceChange))
                #expect(notice.reasonText == "目標に届いたので、1日に減らす分をなくしていくためです。")
            }

            @Test("期限後の維持に移った週は、今の体重を保つ目標に切り替えたことを言うこと")
            func movedToMaintenance() throws {
                let scene = try WeeklyReviewScene()
                let maintenance = Goal(
                    id: UUID(), startedDay: Self.monday, startingWeightTrendKilograms: 70.5,
                    targetWeightKilograms: 70.5,
                    decidedAt: try Date("2026-10-05T06:10:00+09:00", strategy: .iso8601),
                    timeZone: scene.tokyo, direction: .maintain, achievement: nil,
                    deadlineConfirmation: nil, closure: nil)
                let closed = Goal(
                    id: scene.goal.id, startedDay: scene.goal.startedDay,
                    startingWeightTrendKilograms: scene.goal.startingWeightTrendKilograms,
                    targetWeightKilograms: scene.goal.targetWeightKilograms,
                    decidedAt: scene.goal.decidedAt, timeZone: scene.goal.timeZone,
                    direction: scene.goal.direction, achievement: nil, deadlineConfirmation: nil,
                    closure: Goal.Closure(
                        endedDay: Self.monday, nextGoalId: maintenance.id,
                        endReason: .movedToMaintenance))
                let notice = try #require(
                    try Self.notice(
                        scene: scene, goals: [closed, maintenance], guideGoalId: maintenance.id,
                        kilocalories: 2190, guideKilocalories: 2190, mainReason: .balanceChange))
                #expect(notice.reasonText == "今の体重を保つ目標に切り替えたためです。")
            }
        }

        @Suite("振り返りのカードのペースの1行")
        struct PaceLine {
            @Test("間に合うときは、傾向の1週間の変化を出すこと")
            func onTrack() throws {
                let scene = try WeeklyReviewScene(
                    goal: try Goal.losing(startedOn: CalendarDay(year: 2026, month: 9, day: 1)))
                let records = try ["02", "04", "06", "08"].map {
                    try WeightRecord.manual(
                        71.5, at: "2026-10-\($0)T07:00:00+09:00", in: "Asia/Tokyo")
                }
                let timeline = scene.timeline(
                    reviews: [
                        try scene.deferred(
                            effectiveOn: CalendarDay(year: 2026, month: 10, day: 12),
                            reviewedAt: "2026-10-12T06:10:00+09:00")
                    ],
                    weightRecords: records,
                    weightTrend: WeightTrend(days: [
                        .init(day: CalendarDay(year: 2026, month: 9, day: 27), kilograms: 72.0),
                        .init(day: CalendarDay(year: 2026, month: 10, day: 11), kilograms: 71.0),
                    ]), today: CalendarDay(year: 2026, month: 10, day: 12))

                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.paceText == "間に合うペース・−0.5 kg／週")
            }

            @Test("その週に達成していたら、達成した日を出すこと")
            func achieved() throws {
                let losing = try Goal.losing()
                let goal = Goal(
                    id: losing.id, startedDay: losing.startedDay,
                    startingWeightTrendKilograms: losing.startingWeightTrendKilograms,
                    targetWeightKilograms: losing.targetWeightKilograms,
                    decidedAt: losing.decidedAt, timeZone: losing.timeZone,
                    direction: losing.direction,
                    achievement: Goal.Achievement(
                        achievedDay: CalendarDay(year: 2026, month: 11, day: 8),
                        judgedAt: try Date("2026-11-08T07:30:00+09:00", strategy: .iso8601),
                        timeZone: losing.timeZone),
                    deadlineConfirmation: nil, closure: nil)
                let scene = try WeeklyReviewScene(goal: goal)
                let timeline = scene.timeline(
                    reviews: [
                        try scene.deferred(
                            effectiveOn: CalendarDay(year: 2026, month: 11, day: 9),
                            reviewedAt: "2026-11-09T06:10:00+09:00")
                    ],
                    weightRecords: [], today: CalendarDay(year: 2026, month: 11, day: 9))

                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.paceText == "11月8日に 68.0 kg を達成しました")
            }

            @Test("期限の日を過ぎた週は、期限の日を出すこと")
            func deadlinePassed() throws {
                let scene = try WeeklyReviewScene()
                let timeline = scene.timeline(
                    reviews: [
                        try scene.deferred(
                            effectiveOn: CalendarDay(year: 2026, month: 12, day: 28),
                            reviewedAt: "2026-12-28T06:10:00+09:00")
                    ],
                    weightRecords: [], today: CalendarDay(year: 2026, month: 12, day: 28))

                let card = try #require(WeeklyReviewScene.card(in: timeline))
                #expect(card.paceText == "12月24日が期限でした")
            }
        }

        @Suite("目標がないあいだ")
        struct NoGoal {
            let timeline: Timeline

            init() throws {
                let scene = try WeeklyReviewScene()
                let review = try scene.deferred(
                    effectiveOn: CalendarDay(year: 2026, month: 10, day: 5),
                    reviewedAt: "2026-10-05T06:10:00+09:00")
                timeline = scene.timeline(
                    reviews: [review], goals: [], weightRecords: [],
                    today: CalendarDay(year: 2026, month: 10, day: 5))
            }

            @Test("振り返りのカードも変更の知らせも出さないこと")
            func placesNothing() {
                #expect(timeline.days.flatMap(\.items).isEmpty)
            }
        }
    }
}
