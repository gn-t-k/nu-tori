public import Foundation
import NuToriAPI

/// まだ届いていない記録。作った・直した書き込みが送り待ちに残っていて、サーバーに届いたと分かっていない記録で、タイムラインに薄く描く。
/// 送り待ちはキャッシュと別の置き場で画面から読めないので、同期の働きが送り待ちから作って画面に渡す
public struct UndeliveredRecords: Hashable, Sendable {
    public static let none = UndeliveredRecords(pendingEntries: [])

    /// 読めない送り待ちと、薄く描く記録を持たない種類の送り待ちは読み飛ばす
    public init(pendingEntries: [PendingEntry]) {
        var weightRecordIds: Set<UUID> = []
        var mealIds: Set<UUID> = []
        var dishIds: Set<UUID> = []
        var ingredientIds: Set<UUID> = []
        for entry in pendingEntries {
            switch entry.kind {
            case WeightRecordWrite.kindName:
                guard let pending = try? PendingWeightRecordWrite(entry: entry) else { continue }
                switch pending.write {
                case .createWeightRecord(let record), .correctWeightRecord(let record):
                    weightRecordIds.insert(record.id)
                case .sourceDeletedWeightRecord:
                    continue
                }
            case MealWrite.kindName:
                guard let pending = try? PendingMealWrite(entry: entry) else { continue }
                switch pending.write {
                case .create(let meal): mealIds.insert(meal.id)
                case .update(let mealId, _): mealIds.insert(mealId)
                case .delete: continue
                }
            case DishWrite.kindName:
                guard let pending = try? PendingDishWrite(entry: entry) else { continue }
                switch pending.write {
                case .create(let dish): mealIds.insert(dish.mealId)
                case .update(let correction), .rename(let correction): dishIds.insert(correction.id)
                // 消した料理はキャッシュに無く、どの食事の料理だったかが分からないので、食事を薄く描かない
                case .delete: continue
                }
            case IngredientWrite.kindName:
                guard let pending = try? PendingIngredientWrite(entry: entry) else { continue }
                switch pending.write {
                case .update(let ingredientId, _): ingredientIds.insert(ingredientId)
                }
            default:
                continue
            }
        }
        self.weightRecordIds = weightRecordIds
        self.mealIds = mealIds
        self.dishIds = dishIds
        self.ingredientIds = ingredientIds
    }

    func contains(_ item: Timeline.Item) -> Bool {
        switch item {
        case .weightRecord(let record): weightRecordIds.contains(record.id)
        case .meal(let card):
            mealIds.contains(card.meal.id)
                || card.contents.dishes.contains { contents in
                    dishIds.contains(contents.dish.id)
                        || contents.ingredients.contains { ingredientIds.contains($0.id) }
                }
        case .rejectedWeightLine, .rejectedMealLine, .notice: false
        }
    }

    private let weightRecordIds: Set<UUID>
    /// 作る・直す書き込みがある食事と、料理を足す書き込みがある食事
    private let mealIds: Set<UUID>
    /// 直す書き込みがある料理と材料。食事の画面での直しは、その料理と材料の食事のカードを薄く描く
    private let dishIds: Set<UUID>
    private let ingredientIds: Set<UUID>
}
