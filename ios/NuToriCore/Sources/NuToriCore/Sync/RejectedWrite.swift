public import Foundation
public import NuToriAPI

public struct RejectedWrite: Sendable, Equatable {
    public let writeId: UUID
    public let record: WeightRecord
    public let reason: SyncWriteResult.RejectionReason

    public init(writeId: UUID, record: WeightRecord, reason: SyncWriteResult.RejectionReason) {
        self.writeId = writeId
        self.record = record
        self.reason = reason
    }
}
