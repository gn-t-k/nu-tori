public import Foundation

/// 送り待ちの1件。writeId は書き込みごとに端末で振る ID（冪等の鍵）
public enum SyncWrite: Sendable, Equatable {
    case createWeightRecord(writeId: UUID, record: NewWeightRecord)
    case updateWeightRecord(writeId: UUID, correction: WeightRecordCorrection)
}
