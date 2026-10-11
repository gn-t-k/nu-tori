import Foundation
import NuToriCore
import Testing

extension Notice {
    /// issuedAt は ISO 8601 の時刻。東京で出した、その日の体重の知らせ
    static func missedWeightRecord(issuedAt: String) throws -> Notice {
        let timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let issued = try Date(issuedAt, strategy: .iso8601)
        let day = CalendarDay(containing: issued, in: timeZone)
        return Notice(
            id: Notice.id(kind: .missedWeightRecord, targetDay: day),
            kind: .missedWeightRecord,
            issuedAt: issued,
            timeZone: timeZone,
            targetDay: day,
            response: nil
        )
    }
}
