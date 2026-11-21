import Foundation
import NuToriCore

/// 「動きの見本」のタイムラインに流す、画面の中だけの記録。保存も送信もしない。
/// 同期で届く記録と同じく、記録の配列を置き換えて、タイムラインの描き直しで動かす
struct MotionGalleryRecords {
    private(set) var weightRecords: [WeightRecord]
    private(set) var meals: [MealCard]
    private(set) var notices: [Notice]
    private(set) var goals: [Goal] = []
    private(set) var dailyGuides: [DailyGuide] = []
    private(set) var sentTexts: [SentText] = []
    private(set) var statuses: [UUID: SentTextStatus] = [:]
    private let startedDay: CalendarDay

    /// 先週から使っていて、昨日までの体重と食事がある。今日はまだ何も記録していない
    init(today: CalendarDay) {
        startedDay = today.advanced(by: -6)
        weightRecords = (1...6).map { daysAgo in
            .sample(
                72.0 + Double(daysAgo) * 0.1, on: today.advanced(by: -daysAgo), at: 7, 0,
                from: .manual)
        }
        meals = (1...2).map { daysAgo in
            .sampleEstimated(.sample(on: today.advanced(by: -daysAgo), at: 12, 10))
        }
        notices = []
    }

    func snapshot(now: Date, timeZone: TimeZone) -> TimelineSnapshot {
        TimelineSnapshot(
            weightRecords: weightRecords, weightTrend: nil,
            initialPull: .completed(startedDay: startedDay), rejectedLines: [], meals: meals,
            notices: notices, goals: goals, dailyGuides: dailyGuides, weeklyReviews: [],
            expenditureEstimates: [], subscriptionStatus: nil, undelivered: .none,
            conversation: Timeline.Conversation(
                sentTexts: sentTexts, statuses: statuses, replies: [], streams: [:]),
            today: CalendarDay(containing: now, in: timeZone), now: now, timeZone: timeZone)
    }

    // MARK: 体重

    /// 今日の体重の知らせを、答えていない形で出す。今日の体重の記録は消す
    mutating func showWeightNotice(today: CalendarDay) {
        weightRecords.removeAll { $0.day == today }
        notices.removeAll { $0.kind == .missedWeightRecord(targetDay: today) }
        notices.append(.sampleMissedWeightRecord(on: today, respondedAt: nil))
    }

    mutating func save(_ write: WeightEntry.Write) {
        switch write {
        case .create(let kilograms, let instant, let timeZone):
            weightRecords.append(
                WeightRecord(
                    id: UUID(), kilograms: kilograms, instant: instant, timeZone: timeZone,
                    inputSource: .manual, version: 1))
        case .correct(let record):
            weightRecords.removeAll { $0.id == record.id }
            weightRecords.append(record)
        }
    }

    /// 答えていない体重の知らせに、答えた時刻を付ける。サーバーと同じく、体重の記録とは別の保存で届く
    mutating func answerWeightNotices(at instant: Date, timeZone: TimeZone) {
        notices = notices.map { notice in
            guard notice.response == nil, notice.kind != .goalSetup else { return notice }
            return notice.answered(at: instant, timeZone: timeZone)
        }
    }

    // MARK: 食事

    /// 同じ ID の食事を置き換える。無ければ足す
    mutating func put(_ card: MealCard) {
        meals.removeAll { $0.meal.id == card.meal.id }
        meals.append(card)
    }

    mutating func delete(mealId: UUID) {
        meals.removeAll { $0.meal.id == mealId }
    }

    // MARK: 文章

    mutating func send(_ sentText: SentText) {
        sentTexts.append(sentText)
    }

    /// 送った文章を食事と読んだ。文章の食事は推定の途中で届く
    mutating func readAsMeal(_ sentText: SentText, meal: Meal) {
        statuses[sentText.id] = SentTextStatus(classification: .meal, reply: .notRequested)
        put(MealCard(meal: meal, status: .estimating, recordedOnThisDevice: true))
    }

    // MARK: 目標

    /// 目標を立てる知らせを、答えていない形で出す。立てた目標は消す
    mutating func showGoalSetupNotice(today: CalendarDay) {
        goals = []
        dailyGuides = []
        notices.removeAll { $0.kind == .goalSetup }
        notices.append(.sampleGoalSetup(on: today, answered: false))
    }

    /// 今日から 90 日で減らす目標を立て、目標を立てる知らせに答える
    mutating func decideGoal(today: CalendarDay, at instant: Date, timeZone: TimeZone) {
        let goal = Goal(
            id: UUID(), startedDay: today, startingWeightTrendKilograms: 72.0,
            targetWeightKilograms: 69.5, decidedAt: instant, timeZone: timeZone,
            direction: .lose(
                Goal.WeightChange(deadlineDay: today.advanced(by: 90), pacePlan: .standard)),
            achievement: nil, deadlineConfirmation: nil, closure: nil)
        goals = [goal]
        dailyGuides = [.sample(for: goal)]
        notices = notices.map { notice in
            notice.kind == .goalSetup && notice.response == nil
                ? notice.answered(at: instant, timeZone: timeZone) : notice
        }
    }
}

extension Notice {
    fileprivate func answered(at instant: Date, timeZone: TimeZone) -> Notice {
        Notice(
            id: id, kind: kind, issuedAt: issuedAt, timeZone: self.timeZone,
            response: Notice.Response(respondedAt: instant, timeZone: timeZone))
    }
}
