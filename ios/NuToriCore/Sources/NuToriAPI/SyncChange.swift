public import Foundation

/// 取りに行って届いた変更1件
public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    /// サーバーは削除の印を返し直すので、同じ ID で2度届くことがある
    case weightRecordDeletion(recordId: UUID)
    /// 知らない種類、または知っている種類でも中身を読めなかったもの。読み飛ばして通し番号を進める
    case unknown(kind: String)
}
