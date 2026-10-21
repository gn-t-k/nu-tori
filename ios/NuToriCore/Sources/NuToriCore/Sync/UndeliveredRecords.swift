public import Foundation

/// まだ届いていない記録。作った・直した書き込みが送り待ちに残っていて、サーバーに届いたと分かっていない記録で、タイムラインに薄く描く。
/// 送り待ちはキャッシュと別の置き場で画面から読めないので、同期の働きが送り待ちから作って画面に渡す
public struct UndeliveredRecords: Hashable, Sendable {
    public static let none = UndeliveredRecords(records: [])

    /// 送り待ちの書き込みが、届くまで薄く描く記録。どの種類の記録かと、その ID
    public struct Record: Hashable, Sendable {
        public let kind: RecordKindName
        public let id: UUID

        public init(kind: RecordKindName, id: UUID) {
            self.kind = kind
            self.id = id
        }
    }

    public init(records: some Sequence<Record>) {
        self.records = Set(records)
    }

    /// どの記録を薄く描くかは、送り待ちの種類（`RecordKindWrites.undeliveredRecords(of:)`）が決める。
    /// 登録簿に無い種類と、サーバーだけが書く種類の送り待ちは読み飛ばす
    public init(pendingEntries: [PendingEntry], kinds: [any SyncedRecordKind]) {
        let writesByName = Dictionary(
            kinds.compactMap { kind in kind.writes.map { (kind.name, $0) } },
            uniquingKeysWith: { first, _ in first })
        self.init(
            records: pendingEntries.flatMap { entry in
                writesByName[entry.kind]?.undeliveredRecords(of: entry) ?? []
            })
    }

    func contains(_ item: Timeline.Item) -> Bool {
        switch item {
        case .weightRecord(let record): contains(.weightRecord, id: record.id)
        // 食事の画面での料理と材料の直しは、その料理と材料の食事のカードを薄く描く
        case .meal(let card):
            contains(.meal, id: card.meal.id)
                || card.contents.dishes.contains { contents in
                    contains(.dish, id: contents.dish.id)
                        || contents.ingredients.contains { contains(.ingredient, id: $0.id) }
                }
        case .sentText(let bubble): containsSentText(id: bubble.sentText.id)
        case .rejectedWeightLine, .rejectedMealLine, .notice, .goalSetupNotice,
            .rejectedSentTextLine, .weeklyReviewCard, .dailyGuideChangeNotice, .goalNotice,
            .reply, .subscriptionNotice:
            false
        }
    }

    /// 作る・会話として送り直す・送り直すの書き込みが送り待ちに残っている送った文章か
    func containsSentText(id sentTextId: UUID) -> Bool {
        contains(.sentText, id: sentTextId)
    }

    private let records: Set<Record>

    private func contains(_ kind: RecordKindName, id: UUID) -> Bool {
        records.contains(Record(kind: kind, id: id))
    }
}
