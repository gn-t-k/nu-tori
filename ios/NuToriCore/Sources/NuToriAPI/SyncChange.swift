public import Foundation

public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    /// サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
    case weightRecordDeletion(recordId: UUID)
    case accountSettings(SyncedAccountSettings)
    case dish(SyncedDish)
    case dishDeletion(dishId: UUID)
    case dishEstimationStatus(SyncedDishEstimationStatus)
    /// 料理の削除の印と、別の変更で届く。届く順は約束しない
    case dishEstimationStatusDeletion(dishId: UUID)
    case ingredient(SyncedIngredient)
    case ingredientDeletion(ingredientId: UUID)
    case meal(SyncedMeal)
    case mealDeletion(mealId: UUID)
    case mealEstimationStatus(SyncedMealEstimationStatus)
    /// 食事の削除の印と、別の変更で届く。届く順は約束しない
    case mealEstimationStatusDeletion(mealId: UUID)
    case notice(SyncedNotice)
    /// サーバーからは届かない（知らせは削除の印を持たない）。受け付けなかった知らせの書き込みで、
    /// サーバーに知らせが無いときに、端末がキャッシュから外すのに使う
    case noticeRemoval(noticeId: UUID)
    case usualWeighingTime(SyncedUsualWeighingTime)
    /// 並び全体。届いたらキャッシュを置き換える
    case weightTrend(SyncedWeightTrend)
    /// 体重記録が1つも無くなった。傾向のキャッシュを空にする
    case weightTrendAbsence
    /// 知らない種類と読めない中身。サーバーが種類を足しても、古い版のアプリの同期が止まらないように、落とさずに持つ
    case unknown(kind: String)
}
