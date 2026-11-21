import Foundation
import NuToriCore
import UIKit

/// 「動きの見本」に流す作り物の記録。TestFlight の版でも動かすので、プレビューの見本（`#if DEBUG` の `<型>+PreviewSample.swift`）を使わず、ここに持つ
enum MotionGallerySample {
    static func weightRecord(_ kilograms: Double, at instant: Date, timeZone: TimeZone)
        -> WeightRecord
    {
        WeightRecord(
            id: UUID(), kilograms: kilograms, instant: instant, timeZone: timeZone,
            inputSource: .manual, version: 1)
    }

    static func meal(_ entry: Meal.Entry, photoIds: [UUID], at instant: Date, timeZone: TimeZone)
        -> Meal
    {
        Meal(
            id: UUID(), eatenAt: instant,
            eatenUtcOffsetSeconds: timeZone.secondsFromGMT(for: instant), sentAt: instant,
            sentTimeZone: timeZone, entry: entry, photoIds: photoIds)
    }

    /// 推定できた食事。親子丼と味噌汁の2品
    static func estimated(_ meal: Meal) -> MealCard {
        let oyakodon = dish(meal, 0, "親子丼")
        let misoSoup = dish(meal, 1, "味噌汁")
        return MealCard(
            meal: meal, status: .estimated, recordedOnThisDevice: true,
            dishes: [oyakodon, misoSoup],
            ingredients: [
                ingredient(
                    oyakodon, 0, "ご飯", 200, kcal: 156, protein: 2.5, fat: 0.3, carbohydrate: 37.1),
                ingredient(
                    oyakodon, 1, "鶏もも肉", 80, kcal: 190, protein: 16.6, fat: 14.2, carbohydrate: 0),
                ingredient(
                    oyakodon, 2, "卵", 50, kcal: 142, protein: 12.2, fat: 10.2, carbohydrate: 0.4),
                ingredient(
                    misoSoup, 0, "味噌", 18, kcal: 190, protein: 12.5, fat: 6.0, carbohydrate: 21.9),
            ], dishEstimationStatuses: [:], unsentDishIds: [])
    }

    /// 今日の体重の知らせ。今出した
    static func weightNotice(on day: CalendarDay, at instant: Date, timeZone: TimeZone) -> Notice {
        let kind = Notice.Kind.missedWeightRecord(targetDay: day)
        return Notice(
            id: Notice.id(of: kind), kind: kind, issuedAt: instant, timeZone: timeZone,
            response: nil)
    }

    /// 目標を立てる知らせ。今出した
    static func goalSetupNotice(at instant: Date, timeZone: TimeZone) -> Notice {
        Notice(
            id: Notice.id(of: .goalSetup), kind: .goalSetup, issuedAt: instant,
            timeZone: timeZone, response: nil)
    }

    /// 今日から 90 日で減らす目標
    static func goal(startedOn day: CalendarDay, at instant: Date, timeZone: TimeZone) -> Goal {
        Goal(
            id: UUID(), startedDay: day, startingWeightTrendKilograms: 72.0,
            targetWeightKilograms: 69.5, decidedAt: instant, timeZone: timeZone,
            direction: .lose(
                Goal.WeightChange(deadlineDay: day.advanced(by: 90), pacePlan: .standard)),
            achievement: nil, deadlineConfirmation: nil, closure: nil)
    }

    static func dailyGuide(for goal: Goal) -> DailyGuide {
        DailyGuide(
            id: UUID(), goalId: goal.id, expenditureEstimateId: UUID(),
            effectiveDay: goal.startedDay, energyKilocalories: 1850, proteinGrams: 130,
            fatGrams: 50, carbohydrateGrams: 220, limitHits: [])
    }

    /// 場面のボタンで入れた食事の写真の代わりの、無地の画像。写真ごとに色を変える
    static func photo(for photoId: UUID) -> UIImage {
        let hue = CGFloat(photoId.uuid.0) / 255
        let size = CGSize(width: 400, height: 300)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: hue, saturation: 0.35, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func dish(_ meal: Meal, _ position: Int, _ name: String) -> Dish {
        Dish(
            id: UUID(), mealId: meal.id, name: name,
            quantity: Dish.Quantity(value: 1, unit: "杯", source: .estimated),
            positionInMeal: position, version: 1)
    }

    /// 値は 100 g あたり
    private static func ingredient(
        _ dish: Dish, _ position: Int, _ name: String, _ grams: Double, kcal: Double,
        protein: Double, fat: Double, carbohydrate: Double
    ) -> Ingredient {
        Ingredient(
            id: UUID(), dishId: dish.id, name: name, quantity: grams, quantitySource: .estimated,
            unit: "g", edibleGramsPerUnit: 1, positionInDish: position, nutrientSource: .estimated,
            nutrients: [
                .energyKcal: kcal, .proteinG: protein, .fatG: fat, .carbohydrateG: carbohydrate,
            ])
    }
}
