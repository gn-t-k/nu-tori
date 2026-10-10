import Foundation
import NuToriCore
import SwiftData

/// 返事。送った文章より先に届くこともあるので、送った文章の ID を値で持つ
@Model
nonisolated final class CachedAiUtterance {
    @Attribute(.unique) var utteranceId: UUID
    var body: String
    var sentTextId: UUID
    /// 指し示す食事。並びが返事の中の並び
    var mealIds: [UUID]

    init(_ utterance: AiUtterance) {
        utteranceId = utterance.id
        body = utterance.body
        sentTextId = utterance.sentTextId
        mealIds = utterance.mealIds
    }

    /// 返事は変わらないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ utterance: AiUtterance) {
        body = utterance.body
        sentTextId = utterance.sentTextId
        mealIds = utterance.mealIds
    }

    func aiUtterance() -> AiUtterance {
        AiUtterance(id: utteranceId, body: body, sentTextId: sentTextId, mealIds: mealIds)
    }

    /// 保存は呼び出し側が行う
    static func upsert(_ utterance: AiUtterance, in context: ModelContext) throws {
        let id = utterance.id
        var descriptor = FetchDescriptor<CachedAiUtterance>(
            predicate: #Predicate { $0.utteranceId == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.apply(utterance)
        } else {
            context.insert(CachedAiUtterance(utterance))
        }
    }
}
