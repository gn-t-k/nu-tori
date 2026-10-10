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
    /// `Meal.Entry.storedName`
    var entry: String
    /// 文章の食事だけが持つ
    var sentTextId: UUID?
    /// 写真の並び順
    var photoIds: [UUID]

    init(_ meal: Meal) {
        mealId = meal.id
        eatenAt = meal.eatenAt
        eatenUtcOffsetSeconds = meal.eatenUtcOffsetSeconds
        sentAt = meal.sentAt
        sentTimeZoneIdentifier = meal.sentTimeZone.identifier
        entry = meal.entry.storedName
        sentTextId = meal.sentTextId
        photoIds = meal.photoIds
    }

    /// 食事は直す手段を持たないが、同じ ID が届き直したときはその値にそろえる
    func apply(_ meal: Meal) {
        eatenAt = meal.eatenAt
        eatenUtcOffsetSeconds = meal.eatenUtcOffsetSeconds
        sentAt = meal.sentAt
        sentTimeZoneIdentifier = meal.sentTimeZone.identifier
        entry = meal.entry.storedName
        sentTextId = meal.sentTextId
        photoIds = meal.photoIds
    }

    func meal() -> Meal? {
        guard let sentTimeZone = TimeZone(identifier: sentTimeZoneIdentifier),
            let mealEntry = Meal.Entry(storedName: entry, sentTextId: sentTextId)
        else {
            return nil
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
}
