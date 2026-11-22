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
            id: Notice.id(of: .missedWeightRecord(targetDay: day)),
            kind: .missedWeightRecord(targetDay: day),
            issuedAt: issued,
            timeZone: timeZone,
            response: nil
        )
    }

    /// 東京で出した、答えていない目標を立てる知らせ。issuedAt は ISO 8601 の時刻
    static func goalSetup(issuedAt: String) throws -> Notice {
        Notice(
            id: Notice.id(of: .goalSetup), kind: .goalSetup,
            issuedAt: try Date(issuedAt, strategy: .iso8601),
            timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), response: nil)
    }
}
