import Foundation
import NuToriCore
import SwiftData

/// 知らせ。答えも同じ行に持つ（答えていなければ空）
@Model
nonisolated final class CachedNotice {
    @Attribute(.unique) var noticeId: UUID
    /// `Notice.Kind` の `storedName`
    var kind: String
    var issuedAt: Date
    var timeZoneIdentifier: String
    /// YYYY-MM-DD。記録忘れの知らせだけにある
    var targetDay: String?
    var respondedAt: Date?
    var responseTimeZoneIdentifier: String?

    init(_ notice: Notice) {
        noticeId = notice.id
        kind = notice.kind.storedName
        issuedAt = notice.issuedAt
        timeZoneIdentifier = notice.timeZone.identifier
        targetDay = notice.targetDay?.yearMonthDay
        respondedAt = notice.response?.respondedAt
        responseTimeZoneIdentifier = notice.response?.timeZone.identifier
    }

    /// 届いた値（サーバーの今の値を含む）にそろえる
    func apply(_ notice: Notice) {
        kind = notice.kind.storedName
        issuedAt = notice.issuedAt
        timeZoneIdentifier = notice.timeZone.identifier
        targetDay = notice.targetDay?.yearMonthDay
        respondedAt = notice.response?.respondedAt
        responseTimeZoneIdentifier = notice.response?.timeZone.identifier
    }

    /// 読めない種類・タイムゾーン・日付の行と、対象の日付の無い記録忘れの知らせの行は nil
    func notice() -> Notice? {
        guard
            let noticeKind = Notice.Kind(
                storedName: kind, targetDay: targetDay.flatMap(CalendarDay.init(yearMonthDay:))),
            let timeZone = TimeZone(identifier: timeZoneIdentifier)
        else {
            return nil
        }
        var response: Notice.Response?
        if let respondedAt {
            guard let identifier = responseTimeZoneIdentifier,
                let responseTimeZone = TimeZone(identifier: identifier)
            else {
                return nil
            }
            response = Notice.Response(respondedAt: respondedAt, timeZone: responseTimeZone)
        }
        return Notice(
            id: noticeId, kind: noticeKind, issuedAt: issuedAt, timeZone: timeZone,
            response: response)
    }
}
