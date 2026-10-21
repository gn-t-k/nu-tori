public import Foundation

/// 送り待ちから作る画面の見え方。まだ届いていない記録と、まだ送れていない料理。
/// 送り待ちはキャッシュと別の置き場で画面から読めないので、同期の働きが送り待ちから作って画面に渡す
public struct PendingAppearance: Hashable, Sendable {
    public static let none = PendingAppearance(undelivered: .none, unsentDishIds: [])

    /// まだ届いていない記録。タイムラインで薄く描く
    public let undelivered: UndeliveredRecords
    /// 送り待ちに料理を足す・名前を直す書き込みがある料理（`DishSyncing.unsentDishIds(in:)`）。食事のカードで、まだ送れていない料理として見せる
    public let unsentDishIds: Set<UUID>

    public init(undelivered: UndeliveredRecords, unsentDishIds: Set<UUID>) {
        self.undelivered = undelivered
        self.unsentDishIds = unsentDishIds
    }

    /// `kinds` は登録簿の種類。どの記録を薄く描くかは、送り待ちの種類が決める
    public init(pendingEntries: [PendingEntry], kinds: [any SyncedRecordKind]) {
        self.init(
            undelivered: UndeliveredRecords(pendingEntries: pendingEntries, kinds: kinds),
            unsentDishIds: DishSyncing.unsentDishIds(in: pendingEntries))
    }
}
