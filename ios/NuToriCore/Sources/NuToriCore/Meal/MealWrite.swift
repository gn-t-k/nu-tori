public import Foundation

/// 食事の書き込み。送り待ちの置き場には、食事の種類の名前と、この中身の JSON で入る
public enum MealWrite: PendingWriteBody {
    case create(Meal)
    /// 撮った時刻を直す。時差・送った時刻・入口は変えない
    case update(mealId: UUID, eatenAt: Date)
    case delete(mealId: UUID)

    public static var kindName: RecordKindName { MealSyncing.kindName }

    public var stored: Stored { Stored(self) }

    public init?(stored: Stored) {
        guard let write = stored.write() else { return nil }
        self = write
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    /// case を足しても、前の版が残した送り待ちはそのまま読める（case ごとのキーで入るため）
    public enum Stored: Codable {
        case create(StoredMeal)
        case update(mealId: UUID, eatenAt: Date)
        case delete(mealId: UUID)

        init(_ write: MealWrite) {
            switch write {
            case .create(let meal): self = .create(StoredMeal(meal))
            case .update(let mealId, let eatenAt): self = .update(mealId: mealId, eatenAt: eatenAt)
            case .delete(let mealId): self = .delete(mealId: mealId)
            }
        }

        func write() -> MealWrite? {
            switch self {
            case .create(let stored): stored.meal().map { .create($0) }
            case .update(let mealId, let eatenAt): .update(mealId: mealId, eatenAt: eatenAt)
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
        /// `Meal.Entry.storedName`
        let entry: String
        /// 文章の食事だけが持つ。キーが無い前の版の送り待ちも読める
        let sentTextId: UUID?
        let photoIds: [UUID]

        init(_ meal: Meal) {
            id = meal.id
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
