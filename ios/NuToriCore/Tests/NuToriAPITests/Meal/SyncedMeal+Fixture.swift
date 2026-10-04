import Foundation
import Testing

@testable import NuToriAPI

extension SyncedMeal {
    static func fixture() throws -> SyncedMeal {
        SyncedMeal(
            id: try #require(UUID(uuidString: NuToriAPIClientTests.MealSync.mealId)),
            eatenAt: Date(timeIntervalSince1970: 1_767_225_600.123),
            eatenUtcOffsetSeconds: 32_400,
            sentAt: Date(timeIntervalSince1970: 1_767_225_660),
            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
            entryMethod: .picked,
            photoIds: [
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")),
                try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c2")),
            ]
        )
    }
}
