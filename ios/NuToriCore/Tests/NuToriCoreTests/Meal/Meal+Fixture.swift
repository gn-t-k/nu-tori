import Foundation
import NuToriCore
import Testing

extension Meal {
    /// 時刻は ISO 8601 の時刻（"2026-09-24T12:10:00+09:00"）。食事の時差は秒
    static func fixture(
        eatenAt: String,
        utcOffsetSeconds: Int = 9 * 3600,
        sentAt: String,
        in sentTimeZoneIdentifier: String = "Asia/Tokyo",
        id: UUID = UUID(),
        entry: Meal.Entry = .picked,
        photoIds: [UUID] = [UUID()]
    ) throws -> Meal {
        try Meal(
            id: id,
            eatenAt: Date(eatenAt, strategy: .iso8601),
            eatenUtcOffsetSeconds: utcOffsetSeconds,
            sentAt: Date(sentAt, strategy: .iso8601),
            sentTimeZone: #require(TimeZone(identifier: sentTimeZoneIdentifier)),
            entry: entry,
            photoIds: photoIds
        )
    }
}
