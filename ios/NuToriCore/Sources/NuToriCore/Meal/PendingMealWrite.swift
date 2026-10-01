public import Foundation

/// 食事の送り待ち。送り待ちの置き場には、食事の種類の名前と、この中身の JSON で入る
public struct PendingMealWrite: Sendable, Equatable {
    public let writeId: UUID
    public let enqueuedAt: Date
    public let write: Write

    public init(writeId: UUID, enqueuedAt: Date, write: Write) {
        self.writeId = writeId
        self.enqueuedAt = enqueuedAt
        self.write = write
    }

    public enum Write: Sendable, Equatable {
        case create(Meal)
        case delete(mealId: UUID)
    }

    public init(entry: PendingEntry) throws {
        let content: Content
        do {
            content = try JSONDecoder().decode(Content.self, from: entry.content)
        } catch {
            throw PendingWrite.InvalidEntryError(kind: entry.kind)
        }
        self.init(
            writeId: entry.writeId,
            enqueuedAt: entry.enqueuedAt,
            write: try content.write(kind: entry.kind)
        )
    }

    public func entry() throws -> PendingEntry {
        PendingEntry(
            writeId: writeId,
            enqueuedAt: enqueuedAt,
            kind: MealSyncing.kindName,
            content: try JSONEncoder().encode(Content(write))
        )
    }

    /// 送り待ちに保存する JSON。キーを足すときは、無くても読める形にする（`docs/agents/sync.md`「置き場の約束」）
    private enum Content: Codable {
        case create(StoredMeal)
        case delete(mealId: UUID)

        init(_ write: Write) {
            switch write {
            case .create(let meal): self = .create(StoredMeal(meal))
            case .delete(let mealId): self = .delete(mealId: mealId)
            }
        }

        func write(kind: RecordKindName) throws -> Write {
            switch self {
            case .create(let stored): .create(try stored.meal(kind: kind))
            case .delete(let mealId): .delete(mealId: mealId)
            }
        }
    }

    private struct StoredMeal: Codable {
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

        func meal(kind: RecordKindName) throws -> Meal {
            guard let sentTimeZone = TimeZone(identifier: sentTimeZoneIdentifier),
                let mealEntry = MealDraft.Entry(rawValue: entry)
            else {
                throw PendingWrite.InvalidEntryError(kind: kind)
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
