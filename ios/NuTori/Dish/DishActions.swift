import Foundation
import NuToriCore

/// 料理の画面から、料理の名前・量と材料の量を直し、料理を消す操作。
/// どれも、インターネットにつながらなくても、その場でキャッシュに当たり、書き込みが送り待ちに並ぶ
struct DishActions {
    /// 名前の欄を確定したとき。前後の空白を除いて空の名前と、今と同じ名前は送らない（画面は前の名前に戻す）
    let rename: (_ dish: Dish, _ typedName: String) async -> Void
    /// 量の欄を確定したとき。材料の量も同じ割合で変わる。範囲の外の量と今と同じ量は送らない
    let correctQuantity: (_ dish: Dish, _ value: Double) async -> Void
    /// 材料の量の欄を確定したとき。料理の量は変わらない
    let correctIngredientQuantity: (_ ingredient: Ingredient, _ quantity: Double) async -> Void
    /// 「この料理を削除」（最後の1品でないとき）
    let delete: (_ dish: Dish) async -> Void
}

#if DEBUG
    extension DishActions {
        /// プレビューで押しても何もしない操作
        static var noop: DishActions {
            DishActions(
                rename: { _, _ in },
                correctQuantity: { _, _ in },
                correctIngredientQuantity: { _, _ in },
                delete: { _ in })
        }
    }
#endif
