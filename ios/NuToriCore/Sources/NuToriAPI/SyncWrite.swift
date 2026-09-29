public import Foundation

/// writeId は書き込みごとに振る冪等の鍵
public enum SyncWrite: Sendable, Equatable {
    case createWeightRecord(writeId: UUID, record: NewWeightRecord)
    case updateWeightRecord(writeId: UUID, correction: WeightRecordCorrection)
    /// 消すかどうかはサーバーが決める。直した記録は残る
    case sourceDeletedWeightRecord(writeId: UUID, weightRecordId: UUID)
    /// アカウントの設定は、記録が無くても直す書き込みで送る。サーバーが無ければ作る
    case updateAccountSettings(writeId: UUID, settings: SyncedAccountSettings)
}
