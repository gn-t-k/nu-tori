import Foundation

/// 食事の画面に、受け付けなかった1行（`RejectedMealLine`）を置いた並び。置き場は `RejectedMealLine.placement(in:)`。
/// タイムラインのカードを外した位置の1行（`.timeline`）は、タイムラインが置く
public struct MealScreenList: Hashable, Sendable {
    /// 時刻の下に置く1行
    public let belowEatenAt: [RejectedMealLine]
    /// 料理の一覧。料理の行の下の1行と、料理の行を外した位置（その並び順の位置）の1行を並べる
    public let dishes: [Item<DishContents>]

    /// `rejectedLines` は、ほかの食事と体重の1行を含んでよい（この食事の1行だけを置く）
    public init(card: MealCard, rejectedLines: [RejectedLine]) {
        let lines = rejectedLines.compactMap(\.mealLine).filter { $0.meal.id == card.meal.id }
        var belowEatenAt: [RejectedMealLine] = []
        var belowDish: [UUID: [RejectedMealLine]] = [:]
        var inList: [(position: Int, line: RejectedMealLine)] = []
        for line in lines {
            switch line.placement(in: card) {
            case .belowEatenAt: belowEatenAt.append(line)
            case .belowDish(let dishId): belowDish[dishId, default: []].append(line)
            case .inDishList(let position): inList.append((position, line))
            case .timeline, .belowIngredient, .inIngredientList: break
            }
        }
        self.belowEatenAt = belowEatenAt
        dishes = Item.interleaving(
            card.contents.dishes.map { ($0.dish.positionInMeal, $0, belowDish[$0.dish.id] ?? []) },
            inList)
    }

    /// 並びの1つ。記録の行（料理・材料）とその下の1行か、記録の行を外した位置の1行
    public enum Item<Record: Hashable & Sendable>: Hashable, Sendable {
        case record(Record, below: [RejectedMealLine])
        case rejected(RejectedMealLine)

        public var record: Record? {
            if case .record(let record, _) = self { record } else { nil }
        }

        /// 記録の行の下の1行か、外した位置の1行
        public var lines: [RejectedMealLine] {
            switch self {
            case .record(_, let below): below
            case .rejected(let line): [line]
            }
        }

        /// 外した位置の1行は、その並び順より前（同じ並び順を含む）の記録の後ろに置く
        static func interleaving(
            _ records: [(position: Int, record: Record, below: [RejectedMealLine])],
            _ lines: [(position: Int, line: RejectedMealLine)]
        ) -> [Item] {
            var items: [Item] = []
            var remaining = lines
            for record in records {
                let before = remaining.filter { $0.position < record.position }
                remaining.removeAll { $0.position < record.position }
                items += before.map { .rejected($0.line) }
                items.append(.record(record.record, below: record.below))
            }
            return items + remaining.map { .rejected($0.line) }
        }
    }
}

extension MealScreenList.Item where Record == DishContents {
    public var dish: DishContents? { record }

    /// 一覧の行の ID。料理の行は料理の ID、料理の行を外した位置の1行は、その1行が指す記録の ID
    public var rowId: String { rowId(recordId: record?.dish.id) }
}

extension MealScreenList.Item where Record == Ingredient {
    public var ingredient: Ingredient? { record }

    /// 一覧の行の ID。材料の行は材料の ID、材料の行を外した位置の1行は、その1行が指す記録の ID
    public var rowId: String { rowId(recordId: record?.id) }
}

extension MealScreenList.Item {
    fileprivate func rowId(recordId: UUID?) -> String {
        switch self {
        case .record: "record-\(recordId?.uuidString ?? "")"
        case .rejected(let line): "rejected-\(line.recordId.uuidString)"
        }
    }
}

/// 料理の画面に、受け付けなかった1行を置いた並び
public struct DishScreenList: Hashable, Sendable {
    /// 名前と量の下に置く1行
    public let belowHeader: [RejectedMealLine]
    /// 材料の一覧。材料の行の下の1行と、材料の行を外した位置（その並び順の位置）の1行を並べる
    public let ingredients: [MealScreenList.Item<Ingredient>]

    /// `card` は料理の食事の今のカード。`rejectedLines` は、ほかの記録の1行を含んでよい
    public init(contents: DishContents, in card: MealCard, rejectedLines: [RejectedLine]) {
        let dishId = contents.dish.id
        let lines = rejectedLines.compactMap(\.mealLine).filter { $0.meal.id == card.meal.id }
        var belowHeader: [RejectedMealLine] = []
        var belowIngredient: [UUID: [RejectedMealLine]] = [:]
        var inList: [(position: Int, line: RejectedMealLine)] = []
        for line in lines {
            switch line.placement(in: card) {
            case .belowDish(dishId): belowHeader.append(line)
            case .belowIngredient(let ingredientId):
                belowIngredient[ingredientId, default: []].append(line)
            case .inIngredientList(dishId, let position): inList.append((position, line))
            // ほかの料理の1行
            case .timeline, .belowEatenAt, .belowDish, .inDishList, .inIngredientList:
                break
            }
        }
        self.belowHeader = belowHeader
        ingredients = MealScreenList.Item.interleaving(
            contents.ingredients.map { ($0.positionInDish, $0, belowIngredient[$0.id] ?? []) },
            inList)
    }
}
