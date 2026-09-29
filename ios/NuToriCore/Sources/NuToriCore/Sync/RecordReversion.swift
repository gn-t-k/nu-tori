public import Foundation

public enum RecordReversion: Sendable, Equatable {
    case restore(WeightRecord)
    case remove(recordId: UUID)
}
