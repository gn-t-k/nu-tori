public import Foundation

/// 料理を消す操作で消すもの。最後の1品なら、料理を消す書き込みでなく食事を消す書き込みを送る（画面は先に確かめる）
public enum DishRemoval: Sendable, Equatable {
    case dish(dishId: UUID)
    /// 最後の1品。食事と写真をすべて消す
    case meal(mealId: UUID)

    /// 最後の1品かを、キャッシュの料理で数える。推定中・翌日に推定・まだ送れていない料理と、推定し直しが通らなかった料理も、
    /// キャッシュにある料理として1品に数える。`dishes` はほかの食事の料理を含んでよい。キャッシュに無い料理は、料理だけを消す
    public init(removing dishId: UUID, among dishes: [Dish]) {
        guard let dish = dishes.first(where: { $0.id == dishId }),
            !dishes.contains(where: { $0.mealId == dish.mealId && $0.id != dishId })
        else {
            self = .dish(dishId: dishId)
            return
        }
        self = .meal(mealId: dish.mealId)
    }
}
