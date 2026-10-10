import Foundation
import NuToriCore
import Testing

extension SentText {
    /// 時刻は ISO 8601 の時刻（"2026-09-24T12:10:00+09:00"）
    static func fixture(
        _ body: String = "朝はパン",
        sentAt: String,
        in timeZoneIdentifier: String = "Asia/Tokyo",
        id: UUID = UUID()
    ) throws -> SentText {
        try SentText(
            id: id, body: body, sentAt: Date(sentAt, strategy: .iso8601),
            timeZone: #require(TimeZone(identifier: timeZoneIdentifier)))
    }
}
