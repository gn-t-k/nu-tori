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
        case correctWeightRecord(WeightRecord, previous: WeightRecord)
        /// ヘルスケアで元のサンプルが消えた体重記録。消すかどうかはサーバーが決める
        case sourceDeletedWeightRecord(recordId: UUID)
    }
}
