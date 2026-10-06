import Foundation

/// 料理の画面へ潜る行き先。画面は、そのときの食事のカードから料理の ID で引いて描く
nonisolated struct DishRoute: Hashable {
    let dishId: UUID
}
