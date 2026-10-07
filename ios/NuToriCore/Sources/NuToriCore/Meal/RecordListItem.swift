import Foundation

/// 受け付けなかった1行を置いた記録の並び（食事の画面の料理の一覧、料理の画面の材料の一覧）の1つ。
/// 記録の行（料理・材料）とその下の1行か、記録の行を外した位置の1行
public enum RecordListItem<Record: Hashable & Sendable>: Hashable, Sendable {
    case record(Record, below: [RejectedMealLine])
    case rejected(RejectedMealLine)

    public var record: Record? {
        if case .record(let record, _) = self { record } else { nil }
    }

    /// 記録の行の下の1行か、外した位置の1行
    public var lines: [RejectedMealLine] {
        switch self {
        case .record(_, let below): below
        case .rejected(let line): [line]
        }
    }

    /// 外した位置の1行は、その並び順より前（同じ並び順を含む）の記録の後ろに置く
    static func interleaving(
        _ records: [(position: Int, record: Record, below: [RejectedMealLine])],
        _ lines: [(position: Int, line: RejectedMealLine)]
    ) -> [RecordListItem] {
        var items: [RecordListItem] = []
        var remaining = lines
        for record in records {
            let before = remaining.filter { $0.position < record.position }
            remaining.removeAll { $0.position < record.position }
            items += before.map { .rejected($0.line) }
            items.append(.record(record.record, below: record.below))
        }
        return items + remaining.map { .rejected($0.line) }
    }

    /// 一覧の行の ID。記録の行は記録の ID、記録の行を外した位置の1行は、その1行が指す記録の ID
    fileprivate func rowId(recordId: (Record) -> UUID) -> String {
        switch self {
        case .record(let record, _): "record-\(recordId(record).uuidString)"
        case .rejected(let line): "rejected-\(line.recordId.uuidString)"
        }
    }
}

extension RecordListItem where Record == DishContents {
    public var dish: DishContents? { record }

    public var rowId: String { rowId { $0.dish.id } }
}

extension RecordListItem where Record == Ingredient {
    public var ingredient: Ingredient? { record }

    public var rowId: String { rowId { $0.id } }
}
