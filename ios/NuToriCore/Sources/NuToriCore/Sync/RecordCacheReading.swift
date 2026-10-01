public import Foundation

/// キャッシュの記録を読む口。同期の働きとヘルスケアの取り込みが、今の値を見て判断するために使う。
/// 書く口は、箱の `apply` の1つだけ
public protocol RecordCacheReading: Sendable {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    func weightRecords() async throws -> [WeightRecord]

    func accountSettings() async throws -> AccountSettings?

    /// 食事の ID ごとの推定の状態。食事より先に届いた状態も含む
    func mealEstimationStatuses() async throws -> [UUID: MealEstimationStatus]
}
