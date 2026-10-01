public import Foundation

/// タイムラインに置く食事のカード。食事と、カードに見せる状態、料理と材料、栄養の合計を持つ
public struct MealCard: Hashable, Sendable {
    public let meal: Meal
    public let state: MealCardState
    /// 食事の料理と材料。まだ届いていないものは入らない
    public let contents: MealContents
    public let nutrition: MealNutrition

    /// `status` はキャッシュの推定の状態で、まだ届いていなければ nil。
    /// `recordedOnThisDevice` は、この端末で記録した（送った端末の）食事か。
    /// `dishes` と `ingredients` は、キャッシュの全部の料理・材料でよい（この食事のものを取り出す）
    public init(
        meal: Meal,
        status: MealEstimationStatus?,
        recordedOnThisDevice: Bool,
        dishes: [Dish],
        ingredients: [Ingredient]
    ) {
        self.meal = meal
        let state = MealCardState(status: status, recordedOnThisDevice: recordedOnThisDevice)
        self.state = state
        let contents = MealContents(mealId: meal.id, dishes: dishes, ingredients: ingredients)
        self.contents = contents
        nutrition = MealNutrition(state: state, contents: contents)
    }

    /// 料理と材料がまだ届いていない食事のカード
    public init(meal: Meal, status: MealEstimationStatus?, recordedOnThisDevice: Bool) {
        self.init(
            meal: meal, status: status, recordedOnThisDevice: recordedOnThisDevice, dishes: [],
            ingredients: [])
    }

    /// カードに出す時刻。撮った日がカードを置く日と違えば（前の日の写真を選んだ）、撮った日を添える
    public var eatenTime: EatenTime {
        let clock = meal.eatenClockTime
        return meal.day == meal.cardDay ? .clock(clock) : .dayAndClock(meal.day, clock)
    }

    /// カードの上に出す写真の並べ方
    public var photos: Photos {
        switch meal.photoIds.count {
        case 0: .none
        case 1: .single(meal.photoIds[0])
        default: .pair(meal.photoIds[0], meal.photoIds[1], remaining: meal.photoIds.count - 2)
        }
    }

    public enum EatenTime: Hashable, Sendable {
        case clock(ClockTime)
        case dayAndClock(CalendarDay, ClockTime)
    }

    public enum Photos: Hashable, Sendable {
        /// 写真の無い食事（文章で記録する食事。今は作れない）
        case none
        /// 幅いっぱいに出す
        case single(UUID)
        /// 2枚を並べる。残りがあれば、2枚目の上にその枚数を重ねる
        case pair(UUID, UUID, remaining: Int)
    }
}

extension MealNutrition {
    fileprivate init(state: MealCardState, contents: MealContents) {
        switch state {
        case .notSent, .awaitingPhotos, .estimating, .deferredToNextDay:
            self = .pending
        case .estimated:
            // 推定できた食事には、料理が1つ以上ある。無いのは、料理がまだ届いていないとき
            self = contents.dishes.isEmpty ? .pending : .estimated(contents.totals)
        case .noDishes, .failed:
            self = .noFood
        }
    }
}
