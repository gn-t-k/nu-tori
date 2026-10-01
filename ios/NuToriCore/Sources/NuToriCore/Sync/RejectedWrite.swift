public import Foundation
public import NuToriAPI

/// サーバーが受け付けなかった書き込みのうち、画面に1行出すもの
public struct RejectedWrite: Sendable, Equatable {
    public let writeId: UUID
    public let reason: SyncWriteResult.RejectionReason
    public let record: Record

    public init(writeId: UUID, reason: SyncWriteResult.RejectionReason, record: Record) {
        self.writeId = writeId
        self.reason = reason
        self.record = record
    }

    /// 行にする記録
    public enum Record: Sendable, Equatable {
        /// サーバーにその記録の値があるか（`serverHasValue`）で位置を決める。あれば、その値の記録の位置に出す。削除の印か無ければ、作った記録の時刻の位置に出す
        case weightRecord(WeightRecord, serverHasValue: Bool)
        /// サーバーに値が無い食事。カードを置いていた位置に出す
        case meal(Meal)
    }
}
