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
        // 値は apply が入れる。欄をすべて埋めるまで apply を呼べない（Swift の init の決まり）ので、省けない欄に仮の値を入れる
        body = ""
        sentAt = .distantPast
        timeZoneIdentifier = ""
        apply(sentText)
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
