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
    private(set) var rejectedLines: [RejectedLine] = []
    private let startedDay: CalendarDay

    /// 先週から使っていて、昨日までの体重と食事がある。今日はまだ何も記録していない
    init(now: Date, timeZone: TimeZone) {
        startedDay = CalendarDay(containing: now, in: timeZone).advanced(by: -6)
        let daysAgo = { (days: Int) in now.addingTimeInterval(-Double(days) * 24 * 60 * 60) }
        weightRecords = (1...6).map { days in
            MotionGallerySample.weightRecord(
                72.0 + Double(days) * 0.1, at: daysAgo(days), timeZone: timeZone)
        }
        meals = (1...2).map { days in
            MotionGallerySample.estimated(
                MotionGallerySample.meal(
                    .captured, photoIds: [UUID()], at: daysAgo(days), timeZone: timeZone))
        }
        notices = []
    }

    func snapshot(now: Date, timeZone: TimeZone) -> TimelineSnapshot {
        TimelineSnapshot(
            weightRecords: weightRecords, weightTrend: nil,
            initialPull: .completed(startedDay: startedDay), rejectedLines: rejectedLines,
            meals: meals,
            notices: notices, goals: goals, dailyGuides: dailyGuides, weeklyReviews: [],
            expenditureEstimates: [], subscriptionStatus: nil, undelivered: .none,
            conversation: Timeline.Conversation(
                sentTexts: sentTexts, statuses: statuses, replies: [], streams: [:]),
            today: CalendarDay(containing: now, in: timeZone), now: now, timeZone: timeZone)
    }

    // MARK: 体重

    /// 今日の体重の知らせを、答えていない形で出す。今日の体重の記録は消す
    mutating func showWeightNotice(now: Date, timeZone: TimeZone) {
        let today = CalendarDay(containing: now, in: timeZone)
        weightRecords.removeAll { $0.day == today }
        notices.removeAll { $0.kind == .missedWeightRecord(targetDay: today) }
        notices.append(MotionGallerySample.weightNotice(on: today, at: now, timeZone: timeZone))
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

    /// 体重の記録をそのまま足す。あとで `reject(_:)` に渡せるよう、ID を振った記録を受け取る
    mutating func add(_ record: WeightRecord) {
        weightRecords.append(record)
    }

    /// 今記録した体重を、サーバーが受け付けなかった。記録が外れ、その位置に受け付けなかった1行が出る
    mutating func reject(_ record: WeightRecord) {
        weightRecords.removeAll { $0.id == record.id }
        rejectedLines.append(.weight(RejectedWeightLine(record: record, serverHasValue: false)))
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

    /// 食事の時刻を直す
    mutating func correctTime(of card: MealCard, to eatenAt: Date) {
        rebuild(mealId: card.meal.id) { meal, _, _ in
            meal = Meal(
                id: meal.id, eatenAt: eatenAt,
                eatenUtcOffsetSeconds: meal.eatenUtcOffsetSeconds, sentAt: meal.sentAt,
                sentTimeZone: meal.sentTimeZone, entry: meal.entry, photoIds: meal.photoIds)
        }
    }

    /// 料理を足す。見本では推定し直さず、材料の無い1皿として足す。空の名前は足さない
    mutating func addDish(named typed: String, to card: MealCard) {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        rebuild(mealId: card.meal.id) { _, dishes, _ in
            dishes.append(
                Dish(
                    id: UUID(), mealId: card.meal.id, name: name,
                    quantity: Dish.Quantity(value: 1, unit: "皿", source: .estimated),
                    positionInMeal: (dishes.map(\.positionInMeal).max() ?? -1) + 1, version: 1))
        }
    }

    /// 料理の名前を直す。見本では推定し直さず、材料はそのままにする。空の名前と今と同じ名前は直さない
    mutating func rename(_ dish: Dish, to name: String) {
        guard let edit = DishEdit.renaming(dish, to: name) else { return }
        apply(edit)
    }

    /// 料理の量を直す。材料の量も同じ割合で変わる。範囲の外の量と今と同じ量は直さない
    mutating func correctQuantity(of dish: Dish, to value: Double) {
        guard let card = meals.first(where: { $0.meal.id == dish.mealId }),
            let edit = DishEdit.correctingQuantity(
                of: dish, ingredients: card.contents.dishes.flatMap(\.ingredients), to: value)
        else { return }
        apply(edit)
    }

    /// 材料の量を直す。量の出どころは「直した」になる
    mutating func correctQuantity(of ingredient: Ingredient, to quantity: Double) {
        guard
            let mealId = meals.first(where: { card in
                card.contents.dishes.contains { $0.dish.id == ingredient.dishId }
            })?.meal.id
        else { return }
        rebuild(mealId: mealId) { _, _, ingredients in
            ingredients = ingredients.map { old in
                guard old.id == ingredient.id else { return old }
                return Ingredient(
                    id: old.id, dishId: old.dishId, name: old.name, quantity: quantity,
                    quantitySource: .corrected, unit: old.unit,
                    edibleGramsPerUnit: old.edibleGramsPerUnit,
                    positionInDish: old.positionInDish, nutrientSource: old.nutrientSource,
                    nutrients: old.nutrients)
            }
        }
    }

    mutating func delete(_ dish: Dish) {
        rebuild(mealId: dish.mealId) { _, dishes, ingredients in
            dishes.removeAll { $0.id == dish.id }
            ingredients.removeAll { $0.dishId == dish.id }
        }
    }

    /// 直した料理と、量を変えた材料を当てる
    private mutating func apply(_ edit: DishEdit) {
        rebuild(mealId: edit.dish.mealId) { _, dishes, ingredients in
            dishes = dishes.map { $0.id == edit.dish.id ? edit.dish : $0 }
            ingredients = ingredients.map { old in
                edit.ingredients.first { $0.id == old.id } ?? old
            }
        }
    }

    /// 食事のカードを、食事と料理と材料を変えて作り直す
    private mutating func rebuild(
        mealId: UUID, _ change: (inout Meal, inout [Dish], inout [Ingredient]) -> Void
    ) {
        guard let card = meals.first(where: { $0.meal.id == mealId }) else { return }
        var meal = card.meal
        var dishes = card.contents.dishes.map(\.dish)
        var ingredients = card.contents.dishes.flatMap(\.ingredients)
        change(&meal, &dishes, &ingredients)
        put(
            MealCard(
                meal: meal, status: card.status, recordedOnThisDevice: card.recordedOnThisDevice,
                dishes: dishes, ingredients: ingredients, dishEstimationStatuses: [:],
                unsentDishIds: []))
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
    mutating func showGoalSetupNotice(now: Date, timeZone: TimeZone) {
        goals = []
        dailyGuides = []
        notices.removeAll { $0.kind == .goalSetup }
        notices.append(MotionGallerySample.goalSetupNotice(at: now, timeZone: timeZone))
    }

    /// 今日から 90 日で減らす目標を立て、目標を立てる知らせに答える
    mutating func decideGoal(at instant: Date, timeZone: TimeZone) {
        let goal = MotionGallerySample.goal(
            startedOn: CalendarDay(containing: instant, in: timeZone), at: instant,
            timeZone: timeZone)
        goals = [goal]
        dailyGuides = [MotionGallerySample.dailyGuide(for: goal)]
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
