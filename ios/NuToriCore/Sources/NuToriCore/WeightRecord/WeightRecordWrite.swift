public import Foundation

/// 体重記録の書き込み。送り待ちの置き場には、体重記録の種類の名前と、版 1 の形の JSON（`PendingWriteContent`）で入る
public enum WeightRecordWrite: PendingWriteBody {
    case createWeightRecord(WeightRecord)
    case correctWeightRecord(WeightRecord)
    /// ヘルスケアで元のサンプルが消えた体重記録。消すかどうかはサーバーが決める
    case sourceDeletedWeightRecord(recordId: UUID)

    public var kindName: RecordKindName { WeightRecordSyncing.kindName }

    public var stored: PendingWriteContent {
        switch self {
        case .createWeightRecord(let record):
            .create(PendingWriteContent.Record(record))
        case .correctWeightRecord(let record):
            .correct(record: PendingWriteContent.Record(record))
        case .sourceDeletedWeightRecord(let recordId):
            .sourceDeleted(recordId: recordId)
        }
    }

    /// アカウントの設定の JSON は、体重記録の書き込みとして読まない
    public init?(stored: PendingWriteContent) {
        switch stored {
        case .create(let record):
            guard let record = record.weightRecord() else { return nil }
            self = .createWeightRecord(record)
        case .correct(let record):
            guard let record = record.weightRecord() else { return nil }
            self = .correctWeightRecord(record)
        case .sourceDeleted(let recordId):
            self = .sourceDeletedWeightRecord(recordId: recordId)
        case .updateAccountSettings:
            return nil
        }
    }
}

/// 体重記録の送り待ち
public typealias PendingWeightRecordWrite = Pending<WeightRecordWrite>
