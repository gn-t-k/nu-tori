import Foundation

/// 食事の画面に、受け付けなかった1行（`RejectedMealLine`）を置いた並び。置き場は `RejectedMealLine.placement(in:)`。
/// タイムラインのカードを外した位置の1行（`.timeline`）は、タイムラインが置く
public struct MealScreenList: Hashable, Sendable {
    /// 時刻の下に置く1行
    public let belowEatenAt: [RejectedMealLine]
    /// 料理の一覧。料理の行の下の1行と、料理の行を外した位置（その並び順の位置）の1行を並べる
    public let dishes: [RecordListItem<DishContents>]

    /// `rejectedLines` は、ほかの食事と体重の1行を含んでよい（この食事の1行だけを置く）
    public init(card: MealCard, rejectedLines: [RejectedLine]) {
        var belowEatenAt: [RejectedMealLine] = []
        var belowDish: [UUID: [RejectedMealLine]] = [:]
        var inList: [(position: Int, line: RejectedMealLine)] = []
        for line in RejectedMealLine.lines(of: card.meal, among: rejectedLines) {
            switch line.placement(in: card) {
            case .belowEatenAt: belowEatenAt.append(line)
            case .belowDish(let dishId): belowDish[dishId, default: []].append(line)
            case .inDishList(let position): inList.append((position, line))
            case .timeline, .belowIngredient, .inIngredientList: break
            }
        }
        self.belowEatenAt = belowEatenAt
        dishes = RecordListItem.interleaving(
            card.contents.dishes.map { ($0.dish.positionInMeal, $0, belowDish[$0.dish.id] ?? []) },
            inList)
    }
}
