public import Foundation

public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    /// サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
    case weightRecordDeletion(recordId: UUID)
    /// 知らない種類と読めない中身。サーバーが種類を足しても、古い版のアプリの同期が止まらないように、落とさずに持つ
    case unknown(kind: String)
}
