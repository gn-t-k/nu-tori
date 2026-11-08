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
        // 値は apply が入れる。欄をすべて埋めるまで apply を呼べない（Swift の init の決まり）ので、省けない欄に仮の値を入れる
        body = ""
        sentTextId = UUID()
        mealIds = []
        apply(utterance)
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
}
