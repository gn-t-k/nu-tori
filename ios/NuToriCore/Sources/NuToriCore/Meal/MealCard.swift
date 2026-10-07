public import Foundation

/// タイムラインに置く食事のカード。食事と、推定の状態、料理と材料を持ち、カードに見せる状態と栄養の合計を出す
public struct MealCard: Hashable, Sendable {
    public let meal: Meal
    /// キャッシュの推定の状態。まだ届いていなければ nil
    public let status: MealEstimationStatus?
    /// この端末で記録した（送った端末の）食事か
    public let recordedOnThisDevice: Bool
    /// 食事の料理と材料。まだ届いていないものは入らない
    public let contents: MealContents

    /// `dishes` と `ingredients` と `dishEstimationStatuses` は、キャッシュの全部の料理・材料・料理ごとの推定の状態でよい（この食事のものを取り出す）。
    /// `unsentDishIds` は、送り待ちに料理を足す・名前を直す書き込みがある料理（`DishSyncing.unsentDishIds(in:)`）
    public init(
        meal: Meal,
        status: MealEstimationStatus?,
        recordedOnThisDevice: Bool,
        dishes: [Dish],
        ingredients: [Ingredient],
        dishEstimationStatuses: [UUID: DishEstimationStatus],
        unsentDishIds: Set<UUID>
    ) {
        self.meal = meal
        self.status = status
        self.recordedOnThisDevice = recordedOnThisDevice
        contents = MealContents(
            mealId: meal.id, dishes: dishes, ingredients: ingredients,
            dishEstimationStatuses: dishEstimationStatuses, unsentDishIds: unsentDishIds,
            mealState: MealCardState(status: status, recordedOnThisDevice: recordedOnThisDevice))
    }

    /// 料理と材料がまだ届いていない食事のカード
    public init(meal: Meal, status: MealEstimationStatus?, recordedOnThisDevice: Bool) {
        self.init(
            meal: meal, status: status, recordedOnThisDevice: recordedOnThisDevice, dishes: [],
            ingredients: [], dishEstimationStatuses: [:], unsentDishIds: [])
    }

    public var state: MealCardState {
        MealCardState(status: status, recordedOnThisDevice: recordedOnThisDevice)
    }

    public var nutrition: MealNutrition {
        MealNutrition(state: state, contents: contents)
    }

    /// カードの名前の場所。推定が済んだ食事は、料理があれば料理の名前を、無ければ状態の1行を置く（#188）。
    /// 推定を待っている食事は状態の1行だけを置く。推定を待っている食事には料理を足せないので、料理があるのは、
    /// 写真の推定が作った料理が食事の推定の状態より先に届いた一瞬だけ
    public var namePlace: NamePlace {
        switch state {
        case .notSent, .awaitingPhotos, .estimating, .deferredToNextDay:
            return NamePlace(dishNames: nil, statusLine: state.statusLine)
        case .estimated, .noDishes, .failed:
            guard let names = contents.name else {
                return NamePlace(dishNames: nil, statusLine: state.statusLine)
            }
            return NamePlace(dishNames: names, statusLine: nil)
        }
    }

    /// 食事の画面の料理の一覧の場所に置く、食事の写真の推定の状態。推定中と翌日に推定は状態ごとに置き、
    /// 料理なしと推定できなかったは料理が無いあいだだけ置く（#188）
    public var dishListNote: DishListNote? {
        switch state {
        case .notSent, .awaitingPhotos, .estimated: nil
        case .estimating: .estimating
        case .deferredToNextDay: .deferredToNextDay
        case .noDishes: contents.dishes.isEmpty ? .noDishes : nil
        case .failed: contents.dishes.isEmpty ? .failed : nil
        }
    }

    public struct NamePlace: Hashable, Sendable {
        /// 料理の名前を並び順に「・」でつないだもの。料理が無ければ nil
        public let dishNames: String?
        /// 名前の下（料理が無ければ名前の場所）に置く状態の1行。推定中なら回る印を添える
        public let statusLine: String?
    }

    /// 食事の画面の料理の一覧の場所に置く、写真の推定の状態
    public enum DishListNote: Hashable, Sendable {
        /// 回る印と「推定しています…」
        case estimating
        case deferredToNextDay
        case noDishes
        case failed

        /// 太字の1行。推定中は、回る印と並べる
        public var title: String {
            switch self {
            case .estimating: "推定しています…"
            case .deferredToNextDay: "今日はもう推定できません"
            case .noDishes: "写真に料理が見つかりませんでした"
            case .failed: "料理を推定できませんでした"
            }
        }

        public var detail: String? {
            switch self {
            case .estimating, .failed: nil
            case .deferredToNextDay: "明日、この写真を推定します。"
            case .noDishes: "写っていないか、見分けられませんでした。"
            }
        }

        /// 理由の下に添え、続けて「料理を足す」を置く1行（料理なし・推定できなかったの食事に料理が無いあいだ）
        public var addDishHint: String? {
            switch self {
            case .estimating, .deferredToNextDay: nil
            case .noDishes, .failed: "料理の名前を入れると、量と材料を推定します。"
            }
        }
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
            // 料理を足したあとは、分かる料理の分（待っている料理があれば「以上」）
            self = contents.dishes.isEmpty ? .noFood : .estimated(contents.totals)
        }
    }
}
