public import Foundation

/// 送り待ちの1件。writeId は書き込みごとに端末で振る ID（冪等の鍵）
public enum SyncWrite: Sendable, Equatable {
    /// 作る書き込み。サーバーは版を 1 にするので、record の版は送らない
    case createWeightRecord(writeId: UUID, record: SyncedWeightRecord)
    /// 直す書き込み。版は 2 以上。取り込んだ記録の出どころは送らない
    case updateWeightRecord(writeId: UUID, record: SyncedWeightRecord)
    /// 消すかどうかはサーバーが決める。直した記録は残る
    case sourceDeletedWeightRecord(writeId: UUID, weightRecordId: UUID)
}
