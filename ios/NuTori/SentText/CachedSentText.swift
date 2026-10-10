import Foundation
import NuToriCore
import SwiftData

/// 送った文章。作ったあと変わらない
@Model
nonisolated final class CachedSentText {
    @Attribute(.unique) var sentTextId: UUID
    var body: String
    var sentAt: Date
    var timeZoneIdentifier: String

    init(_ sentText: SentText) {
        sentTextId = sentText.id
        body = sentText.body
        sentAt = sentText.sentAt
        timeZoneIdentifier = sentText.timeZone.identifier
    }

    /// 送った文章は直す手段を持たないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ sentText: SentText) {
        body = sentText.body
        sentAt = sentText.sentAt
        timeZoneIdentifier = sentText.timeZone.identifier
    }

    /// 読めないタイムゾーンの行は nil
    func sentText() -> SentText? {
        TimeZone(identifier: timeZoneIdentifier).map {
            SentText(id: sentTextId, body: body, sentAt: sentAt, timeZone: $0)
        }
    }

    /// 保存は呼び出し側が行う
    static func upsert(_ sentText: SentText, in context: ModelContext) throws {
        if let existing = try find(id: sentText.id, in: context) {
            existing.apply(sentText)
        } else {
            context.insert(CachedSentText(sentText))
        }
    }

    static func find(id: UUID, in context: ModelContext) throws -> CachedSentText? {
        var descriptor = FetchDescriptor<CachedSentText>(
            predicate: #Predicate { $0.sentTextId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
