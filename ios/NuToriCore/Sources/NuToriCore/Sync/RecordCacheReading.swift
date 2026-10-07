public import Foundation

/// キャッシュの記録を読む口。同期の働きとヘルスケアの取り込みが、今の値を見て判断するために使う。
/// 書く口は、箱の `apply` の1つだけ
public protocol RecordCacheReading: Sendable {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    func weightRecords() async throws -> [WeightRecord]

    func accountSettings() async throws -> AccountSettings?

    /// 食事の ID ごとの推定の状態。食事より先に届いた状態も含む
    func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus]

    func meals() async throws -> [Meal]

    /// 親の食事がまだ届いていない料理も含む
    func dishes() async throws -> [Dish]

    /// 料理の ID ごとの推定の状態。料理より先に届いた状態も含む
    func dishEstimationStatuses() async throws -> [UUID: DishEstimationStatus]

    /// 親の料理がまだ届いていない材料も含む
    func ingredients() async throws -> [Ingredient]

    /// 答えた知らせも含む
    func notices() async throws -> [Notice]

    /// まだ学んでいなければ nil
    func usualWeighingTime() async throws -> UsualWeighingTime?

    /// 体重記録が1つも無ければ nil
    func weightTrend() async throws -> WeightTrend?
}
