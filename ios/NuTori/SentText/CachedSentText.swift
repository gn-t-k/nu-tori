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
}
