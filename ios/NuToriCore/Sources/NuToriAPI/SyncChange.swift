public import Foundation

public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    /// サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
    case weightRecordDeletion(recordId: UUID)
    case accountSettings(SyncedAccountSettings)
    case meal(SyncedMeal)
    case mealDeletion(mealId: UUID)
    case mealEstimationStatus(SyncedMealEstimationStatus)
    /// 食事の削除の印と、別の変更で届く。届く順は約束しない
    case mealEstimationStatusDeletion(mealId: UUID)
    /// 知らない種類と読めない中身。サーバーが種類を足しても、古い版のアプリの同期が止まらないように、落とさずに持つ
    case unknown(kind: String)
}
