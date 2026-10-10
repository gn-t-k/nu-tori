public import Foundation

/// 受け付けなかった1行。体重の1行か、食事（時刻・料理・材料を含む）の1行か、送った文章の1行
public enum RejectedLine: Hashable, Sendable {
    case weight(RejectedWeightLine)
    case meal(RejectedMealLine)
    case sentText(RejectedSentTextLine)

    init(_ record: RejectedWrite.Record) {
        switch record {
        case .weightRecord(let record, let serverHasValue):
            self = .weight(RejectedWeightLine(record: record, serverHasValue: serverHasValue))
        case .meal(let meal):
            self = .meal(RejectedMealLine(meal: meal))
        case .mealEdit(let line):
            self = .meal(line)
        case .sentText(let line):
            self = .sentText(line)
        }
    }

    public var recordId: UUID {
        switch self {
        case .weight(let line): line.record.id
        case .meal(let line): line.recordId
        case .sentText(let line): line.sentText.id
        }
    }

    public var weightLine: RejectedWeightLine? {
        if case .weight(let line) = self { line } else { nil }
    }

    public var mealLine: RejectedMealLine? {
        if case .meal(let line) = self { line } else { nil }
    }

    public var sentTextLine: RejectedSentTextLine? {
        if case .sentText(let line) = self { line } else { nil }
    }
}
