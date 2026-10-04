public import Foundation

/// 食事の書き込み。送り待ちの置き場には、食事の種類の名前と、この中身の JSON で入る
public enum MealWrite: PendingWriteBody {
    case create(Meal)
    case delete(mealId: UUID)

    public var kindName: RecordKindName { MealSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        guard let write = stored.write() else { return nil }
        self = write
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    public enum Stored: Codable {
        case create(StoredMeal)
        case delete(mealId: UUID)

        init(_ write: MealWrite) {
            switch write {
            case .create(let meal): self = .create(StoredMeal(meal))
            case .delete(let mealId): self = .delete(mealId: mealId)
            }
        }

        func write() -> MealWrite? {
            switch self {
            case .create(let stored): stored.meal().map { .create($0) }
            case .delete(let mealId): .delete(mealId: mealId)
            }
        }
    }

    public struct StoredMeal: Codable {
        let id: UUID
        let eatenAt: Date
        let eatenUtcOffsetSeconds: Int
        let sentAt: Date
        let sentTimeZoneIdentifier: String
        /// `captured` か `picked`
        let entry: String
        let photoIds: [UUID]

        init(_ meal: Meal) {
            id = meal.id
            eatenAt = meal.eatenAt
            eatenUtcOffsetSeconds = meal.eatenUtcOffsetSeconds
            sentAt = meal.sentAt
            sentTimeZoneIdentifier = meal.sentTimeZone.identifier
            entry = meal.entry.rawValue
            photoIds = meal.photoIds
        }

        func meal() -> Meal? {
            guard let sentTimeZone = TimeZone(identifier: sentTimeZoneIdentifier),
                let mealEntry = MealDraft.Entry(rawValue: entry)
            else {
                return nil
            }
            return Meal(
                id: id,
                eatenAt: eatenAt,
                eatenUtcOffsetSeconds: eatenUtcOffsetSeconds,
                sentAt: sentAt,
                sentTimeZone: sentTimeZone,
                entry: mealEntry,
                photoIds: photoIds
            )
        }
    }
}

/// 食事の送り待ち
public typealias PendingMealWrite = Pending<MealWrite>
