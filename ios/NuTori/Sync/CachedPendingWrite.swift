import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedPendingWrite {
    @Attribute(.unique) var writeId: UUID
    var enqueuedAt: Date
    /// `create` か `correct`
    var kindRaw: String
    var recordJSON: Data
    /// 直す書き込みの、直す前の記録。作る書き込みには無い
    var previousJSON: Data?

    init(write: PendingWrite) throws {
        writeId = write.writeId
        enqueuedAt = write.enqueuedAt
        switch write.operation {
        case .createWeightRecord(let record):
            kindRaw = "create"
            recordJSON = try StoredWeightRecord(record).encoded()
            previousJSON = nil
        case .correctWeightRecord(let record, let previous):
            kindRaw = "correct"
            recordJSON = try StoredWeightRecord(record).encoded()
            previousJSON = try StoredWeightRecord(previous).encoded()
        }
    }

    func pendingWrite() throws -> PendingWrite {
        let record = try StoredWeightRecord.decoded(recordJSON).weightRecord()
        let operation: PendingWrite.Operation
        if kindRaw == "create" {
            operation = .createWeightRecord(record)
        } else if kindRaw == "correct" {
            guard let previousJSON else { throw RecordStoreError.missingPrevious }
            operation = .correctWeightRecord(
                record, previous: try StoredWeightRecord.decoded(previousJSON).weightRecord())
        } else {
            throw RecordStoreError.unknownPendingWriteKind(kindRaw)
        }
        return PendingWrite(writeId: writeId, enqueuedAt: enqueuedAt, operation: operation)
    }
}
