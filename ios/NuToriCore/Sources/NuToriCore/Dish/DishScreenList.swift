import Foundation

/// 料理の画面に、受け付けなかった1行を置いた並び
public struct DishScreenList: Hashable, Sendable {
    /// 名前と量の下に置く1行
    public let belowHeader: [RejectedMealLine]
    /// 材料の一覧。材料の行の下の1行と、材料の行を外した位置（その並び順の位置）の1行を並べる
    public let ingredients: [RecordListItem<Ingredient>]

    /// `card` は料理の食事の今のカード。`rejectedLines` は、ほかの記録の1行を含んでよい
    public init(contents: DishContents, in card: MealCard, rejectedLines: [RejectedLine]) {
        let dishId = contents.dish.id
        var belowHeader: [RejectedMealLine] = []
        var belowIngredient: [UUID: [RejectedMealLine]] = [:]
        var inList: [(position: Int, line: RejectedMealLine)] = []
        for line in RejectedMealLine.lines(of: card.meal, among: rejectedLines) {
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
        ingredients = RecordListItem.interleaving(
            contents.ingredients.map { ($0.positionInDish, $0, belowIngredient[$0.id] ?? []) },
            inList)
    }
}
