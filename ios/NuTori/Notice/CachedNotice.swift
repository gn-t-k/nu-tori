import Foundation
import NuToriCore
import SwiftData

/// 知らせ。答えも同じ行に持つ（答えていなければ空）
@Model
nonisolated final class CachedNotice {
    @Attribute(.unique) var noticeId: UUID
    /// `Notice.Kind` の rawValue
    var kind: String
    var issuedAt: Date
    var timeZoneIdentifier: String
    /// YYYY-MM-DD
    var targetDay: String
    var respondedAt: Date?
    var responseTimeZoneIdentifier: String?

    init(_ notice: Notice) {
        noticeId = notice.id
        kind = notice.kind.rawValue
        issuedAt = notice.issuedAt
        timeZoneIdentifier = notice.timeZone.identifier
        targetDay = notice.targetDay.yearMonthDay
        respondedAt = notice.response?.respondedAt
        responseTimeZoneIdentifier = notice.response?.timeZone.identifier
    }

    /// 届いた値（サーバーの今の値を含む）にそろえる
    func apply(_ notice: Notice) {
        kind = notice.kind.rawValue
        issuedAt = notice.issuedAt
        timeZoneIdentifier = notice.timeZone.identifier
        targetDay = notice.targetDay.yearMonthDay
        respondedAt = notice.response?.respondedAt
        responseTimeZoneIdentifier = notice.response?.timeZone.identifier
    }

    /// 読めない種類・タイムゾーン・日付の行は nil
    func notice() -> Notice? {
        guard let noticeKind = Notice.Kind(rawValue: kind),
            let timeZone = TimeZone(identifier: timeZoneIdentifier),
            let day = CalendarDay(yearMonthDay: targetDay)
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
            targetDay: day, response: response)
    }

    /// 保存は呼び出し側が行う
    static func upsert(_ notice: Notice, in context: ModelContext) throws {
        if let existing = try find(id: notice.id, in: context) {
            existing.apply(notice)
        } else {
            context.insert(CachedNotice(notice))
        }
    }

    static func find(id: UUID, in context: ModelContext) throws -> CachedNotice? {
        var descriptor = FetchDescriptor<CachedNotice>(
            predicate: #Predicate { $0.noticeId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
