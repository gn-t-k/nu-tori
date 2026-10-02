public import Foundation

/// 受け付けなかった1行。体重の1行か食事の1行
public enum RejectedLine: Hashable, Sendable {
    case weight(RejectedWeightLine)
    case meal(RejectedMealLine)

    init(_ record: RejectedWrite.Record) {
        switch record {
        case .weightRecord(let record, let serverHasValue):
            self = .weight(RejectedWeightLine(record: record, serverHasValue: serverHasValue))
        case .meal(let meal):
            self = .meal(RejectedMealLine(meal: meal))
        }
    }

    public var recordId: UUID {
        switch self {
        case .weight(let line): line.record.id
        case .meal(let line): line.meal.id
        }
    }

    public var weightLine: RejectedWeightLine? {
        if case .weight(let line) = self { line } else { nil }
    }

    public var mealLine: RejectedMealLine? {
        if case .meal(let line) = self { line } else { nil }
    }
}
