public import Foundation
public import NuToriAPI

/// 送った文章の同期の形。記録の種類の入口のうち、キャッシュの型に依らない部分。
/// 取りに行った変更の見分け方と今の値の読み方、送り待ちから送る書き込み（作る・会話として送り直す・送り直す）を作る
public struct SentTextSyncing: SyncedRecordKind, RecordKindWrites {
    /// 送り待ちの種類の名前。変えると、送り待ちに残った送った文章が読めなくなる
    public static let kindName = RecordKindName.sentText

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { self }

    /// 取りに行った変更のうち、当てる今の値と、外す送った文章の ID（受け付けなかった作る書き込みだけ）
    public struct Current: Sendable, Equatable {
        public let sentTexts: [SentText]
        public let removedSentTextIds: [UUID]
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        let pending = try PendingSentTextWrite(entry: entry)
        switch pending.write {
        case .create(let sentText):
            return .createSentText(writeId: pending.writeId, sentText: SyncedSentText(sentText))
        case .resendAsConversation(let sentTextId):
            return .resendSentTextAsConversation(writeId: pending.writeId, sentTextId: sentTextId)
        case .resend(let sentTextId):
            return .resendSentText(writeId: pending.writeId, sentTextId: sentTextId)
        }
    }

    /// 受け付けなかった作る書き込みは、サーバーに文章が無いときだけ、吹き出しを外して行にする（値があれば、吹き出しがそのまま残る）。
    /// 受け付けなかった送り直す2つは、サーバーの今の値に戻した吹き出しの下に行を出す。
    /// 会話として送り直す書き込みで消した食事は、今の値（送った文章）では戻らず、次に全部取り直すまでキャッシュに無い。
    /// サーバーに文章が無ければ、送り直す2つでも吹き出しを外す（作る書き込みが断られた行がすでに出ている）
    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?,
        shown: ShownRecords
    ) throws -> KindRejection {
        let pending = try PendingSentTextWrite(entry: entry)
        func rejected(_ sentText: SentText, _ subject: RejectedSentTextLine.Subject)
            -> RejectedWrite
        {
            RejectedWrite(
                writeId: pending.writeId, reason: reason,
                record: .sentText(RejectedSentTextLine(sentText: sentText, subject: subject)))
        }
        let removing: [SyncChange] = [.sentTextRemoval(sentTextId: pending.write.sentTextId)]
        switch (pending.write, current) {
        case (.create(let sentText), .absent):
            return KindRejection(
                rejectedWrite: rejected(sentText, .send), removingChanges: removing)
        case (.resendAsConversation, .absent), (.resend, .absent):
            return KindRejection(rejectedWrite: nil, removingChanges: removing)
        case (.resendAsConversation, .value(let change)):
            return KindRejection(
                rejectedWrite: self.current(from: [change]).sentTexts.first.map {
                    rejected($0, .resendAsConversation)
                },
                removingChanges: [])
        case (.resend, .value(let change)):
            return KindRejection(
                rejectedWrite: self.current(from: [change]).sentTexts.first.map {
                    rejected($0, .resend)
                },
                removingChanges: [])
        // 送った文章は削除の印を持たないので、`deleted` は届かない
        case (.create, .value), (.create, .deleted), (.create, nil),
            (.resendAsConversation, .deleted),
            (.resendAsConversation, nil), (.resend, .deleted), (.resend, nil):
            return KindRejection.none
        }
    }

    /// 文章を送ったときの結果。送り待ちに足し、送った文章を、取りに行った変更と同じ形でキャッシュに当てる
    public func sending(_ sentText: SentText, enqueuing write: PendingSentTextWrite) throws
        -> SyncBoxResult
    {
        SyncBoxResult(
            enqueuing: [try write.entry()],
            kindChanges: [KindChanges(kind: name, changes: [.sentText(SyncedSentText(sentText))])]
        )
    }

    /// 会話として送り直したときの結果。送り待ちに足し、その文章から作った食事と、その料理・材料・推定の状態を、
    /// 削除の印と同じ形でキャッシュから消す。`meals`・`dishes`・`ingredients` はキャッシュの今の記録
    public func resendingAsConversation(
        sentTextId: UUID,
        meals: [Meal],
        dishes: [Dish],
        ingredients: [Ingredient],
        enqueuing write: PendingSentTextWrite
    ) throws -> SyncBoxResult {
        let mealIds = meals.filter { $0.sentTextId == sentTextId }.map(\.id)
        let dishIds = dishes.filter { mealIds.contains($0.mealId) }.map(\.id)
        let ingredientIds = ingredients.filter { dishIds.contains($0.dishId) }.map(\.id)
        let kindChanges = [
            KindChanges(
                kind: MealSyncing.kindName, changes: mealIds.map { .mealDeletion(mealId: $0) }),
            KindChanges(
                kind: MealEstimationStatusSyncing.kindName,
                changes: mealIds.map { .mealEstimationStatusDeletion(mealId: $0) }),
            KindChanges(
                kind: DishSyncing.kindName, changes: dishIds.map { .dishDeletion(dishId: $0) }),
            KindChanges(
                kind: DishEstimationStatusSyncing.kindName,
                changes: dishIds.map { .dishEstimationStatusDeletion(dishId: $0) }),
            KindChanges(
                kind: IngredientSyncing.kindName,
                changes: ingredientIds.map { .ingredientDeletion(ingredientId: $0) }),
        ].filter { !$0.changes.isEmpty }
        return SyncBoxResult(enqueuing: [try write.entry()], kindChanges: kindChanges)
    }

    /// 送り直したときの結果。送り待ちに足すだけで、キャッシュは変えない
    public func resending(enqueuing write: PendingSentTextWrite) throws -> SyncBoxResult {
        SyncBoxResult(enqueuing: [try write.entry()])
    }

    /// 取りに行った変更を、今の値の並びにする
    public func current(from changes: [SyncChange]) -> Current {
        var sentTexts: [SentText] = []
        var removedSentTextIds: [UUID] = []
        for change in changes {
            if case .sentText(let sentText) = change {
                sentTexts.append(SentText(sentText))
            } else if case .sentTextRemoval(let sentTextId) = change {
                removedSentTextIds.append(sentTextId)
            }
        }
        return Current(sentTexts: sentTexts, removedSentTextIds: removedSentTextIds)
    }
}

extension SyncedSentText {
    init(_ sentText: SentText) {
        self.init(
            id: sentText.id, body: sentText.body, sentAt: sentText.sentAt,
            timeZone: sentText.timeZone)
    }
}

extension SentText {
    init(_ sentText: SyncedSentText) {
        self.init(
            id: sentText.id, body: sentText.body, sentAt: sentText.sentAt,
            timeZone: sentText.timeZone)
    }
}
