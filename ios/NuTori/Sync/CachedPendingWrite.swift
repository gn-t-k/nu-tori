import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedPendingWrite {
    @Attribute(.unique) var writeId: UUID
    var enqueuedAt: Date
    /// 作る書き込みか、直す書き込みか。直すときは直す前の記録も入る
    var operationJSON: Data

    init(write: PendingWrite) throws {
        writeId = write.writeId
        enqueuedAt = write.enqueuedAt
        operationJSON = try JSONEncoder().encode(StoredPendingOperation(write.operation))
    }

    func pendingWrite() throws -> PendingWrite {
        let operation = try JSONDecoder().decode(StoredPendingOperation.self, from: operationJSON)
        return PendingWrite(
            writeId: writeId, enqueuedAt: enqueuedAt, operation: try operation.pendingOperation())
    }
}

private nonisolated enum StoredPendingOperation: Codable {
    case create(StoredWeightRecord)
    case correct(record: StoredWeightRecord, previous: StoredWeightRecord)
    case sourceDeleted(recordId: UUID)

    init(_ operation: PendingWrite.Operation) {
        switch operation {
        case .createWeightRecord(let record):
            self = .create(StoredWeightRecord(record))
        case .correctWeightRecord(let record, let previous):
            self = .correct(
                record: StoredWeightRecord(record), previous: StoredWeightRecord(previous))
        case .sourceDeletedWeightRecord(let recordId):
            self = .sourceDeleted(recordId: recordId)
        }
    }

    func pendingOperation() throws -> PendingWrite.Operation {
        switch self {
        case .create(let record):
            .createWeightRecord(try record.weightRecord())
        case .correct(let record, let previous):
            .correctWeightRecord(
                try record.weightRecord(), previous: try previous.weightRecord())
        case .sourceDeleted(let recordId):
            .sourceDeletedWeightRecord(recordId: recordId)
        }
    }
}
