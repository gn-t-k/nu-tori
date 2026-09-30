import Foundation
import NuToriCore
import SwiftData

typealias PendingWriteRow = PendingStoreSchemaV1.PendingWriteRow

extension PendingWriteRow {
    convenience init(write: PendingWrite) throws {
        self.init(
            writeId: write.writeId,
            enqueuedAt: write.enqueuedAt,
            operationJSON: try JSONEncoder().encode(StoredPendingOperation(write.operation))
        )
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
    case updateAccountSettings(id: UUID, sendsUsageData: Bool)

    init(_ operation: PendingWrite.Operation) {
        switch operation {
        case .createWeightRecord(let record):
            self = .create(StoredWeightRecord(record))
        case .correctWeightRecord(let record, let previous):
            self = .correct(
                record: StoredWeightRecord(record), previous: StoredWeightRecord(previous))
        case .sourceDeletedWeightRecord(let recordId):
            self = .sourceDeleted(recordId: recordId)
        case .updateAccountSettings(let settings):
            self = .updateAccountSettings(id: settings.id, sendsUsageData: settings.sendsUsageData)
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
        case .updateAccountSettings(let id, let sendsUsageData):
            .updateAccountSettings(AccountSettings(id: id, sendsUsageData: sendsUsageData))
        }
    }
}
