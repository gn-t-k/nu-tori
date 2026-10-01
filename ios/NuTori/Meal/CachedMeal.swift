import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedMeal {
    @Attribute(.unique) var mealId: UUID
    var eatenAt: Date
    var eatenUtcOffsetSeconds: Int
    var sentAt: Date
    var sentTimeZoneIdentifier: String
    /// `captured` か `picked`
    var entry: String
    /// 写真の並び順
    var photoIds: [UUID]

    init(_ meal: Meal) {
        mealId = meal.id
        eatenAt = meal.eatenAt
        eatenUtcOffsetSeconds = meal.eatenUtcOffsetSeconds
        sentAt = meal.sentAt
        sentTimeZoneIdentifier = meal.sentTimeZone.identifier
        entry = Self.storedEntry(meal.entry)
        photoIds = meal.photoIds
    }

    /// 食事は直す手段を持たないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ meal: Meal) {
        eatenAt = meal.eatenAt
        eatenUtcOffsetSeconds = meal.eatenUtcOffsetSeconds
        sentAt = meal.sentAt
        sentTimeZoneIdentifier = meal.sentTimeZone.identifier
        entry = Self.storedEntry(meal.entry)
        photoIds = meal.photoIds
    }

    func meal() -> Meal? {
        guard let sentTimeZone = TimeZone(identifier: sentTimeZoneIdentifier) else { return nil }
        let mealEntry: MealDraft.Entry
        switch entry {
        case "captured": mealEntry = .captured
        case "picked": mealEntry = .picked
        default: return nil
        }
        return Meal(
            id: mealId,
            eatenAt: eatenAt,
            eatenUtcOffsetSeconds: eatenUtcOffsetSeconds,
            sentAt: sentAt,
            sentTimeZone: sentTimeZone,
            entry: mealEntry,
            photoIds: photoIds
        )
    }

    private static func storedEntry(_ entry: MealDraft.Entry) -> String {
        switch entry {
        case .captured: "captured"
        case .picked: "picked"
        }
    }
}
