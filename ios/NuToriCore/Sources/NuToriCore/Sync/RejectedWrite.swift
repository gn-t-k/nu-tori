public import Foundation
public import NuToriAPI

public struct RejectedWrite: Sendable, Equatable {
    public let writeId: UUID
    public let record: WeightRecord
    public let reason: SyncWriteResult.RejectionReason
    /// サーバーにその記録の値があるか。あれば、その値の記録の位置に出す。削除の印か無ければ、作った記録の時刻の位置に出す
    public let serverHasValue: Bool

    public init(
        writeId: UUID,
        record: WeightRecord,
        reason: SyncWriteResult.RejectionReason,
        serverHasValue: Bool
    ) {
        self.writeId = writeId
        self.record = record
        self.reason = reason
        self.serverHasValue = serverHasValue
    }
}
