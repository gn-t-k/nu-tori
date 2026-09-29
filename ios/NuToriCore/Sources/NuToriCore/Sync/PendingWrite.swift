public import Foundation

public struct PendingWrite: Sendable, Equatable {
    public let writeId: UUID
    public let enqueuedAt: Date
    public let operation: Operation

    public init(writeId: UUID, enqueuedAt: Date, operation: Operation) {
        self.writeId = writeId
        self.enqueuedAt = enqueuedAt
        self.operation = operation
    }

    public enum Operation: Sendable, Equatable {
        case createWeightRecord(WeightRecord)
        /// previous は、直す前に手元にあった記録。サーバーが受け付けなかったときに戻す先
        case correctWeightRecord(WeightRecord, previous: WeightRecord)
    }
}
