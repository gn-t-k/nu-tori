import Foundation
import Testing

@testable import NuToriAPI

extension SyncedDish {
    static func fixture(mealId: UUID) throws -> SyncedDish {
        SyncedDish(
            id: try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")),
            mealId: mealId,
            name: "親子丼",
            quantity: 1,
            unit: "杯",
            positionInMeal: 0,
            version: 1
        )
    }
}
