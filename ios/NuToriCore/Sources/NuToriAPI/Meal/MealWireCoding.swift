import Foundation

struct MealWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.meal

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.MealPayload.self).syncedMeal).map { .meal($0) }
        case .deletion: UUID(uuidString: recordId).map { .mealDeletion(mealId: $0) }
        case .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        if case .createMeal(let writeId, let meal) = write {
            return .init(
                recordId: meal.id,
                body: .createMeal(
                    .init(
                        id: writeId.canonicalString,
                        _type: .createMeal,
                        meal: .init(
                            id: meal.id.canonicalString,
                            eatenAt: meal.eatenAt.millisecondsSince1970,
                            eatenAtUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                            sentAt: meal.sentAt.millisecondsSince1970,
                            sentTimeZone: meal.sentTimeZone.identifier,
                            entryMethod: meal.entryMethod.wireName,
                            photos: meal.photoIds.map { .init(id: $0.canonicalString) }
                        )
                    )
                ))
        }
        if case .updateMeal(let writeId, let mealId, let eatenAt) = write {
            return .init(
                recordId: mealId,
                body: .updateMeal(
                    .init(
                        id: writeId.canonicalString, _type: .updateMeal,
                        mealId: mealId.canonicalString, eatenAt: eatenAt.millisecondsSince1970)))
        }
        if case .deleteMeal(let writeId, let mealId) = write {
            return .init(
                recordId: mealId,
                body: .deleteMeal(
                    .init(
                        id: writeId.canonicalString, _type: .deleteMeal,
                        mealId: mealId.canonicalString)))
        }
        return nil
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            if case .meal(let meal) = change {
                return .value(id: meal.id, record: SyncChange.MealPayload(meal))
            }
            if case .mealDeletion(let mealId) = change {
                return .deletion(id: mealId)
            }
            return nil
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            if case .createMeal(let write) = wire {
                let meal = write.meal
                // 端末が作る食事は写真の食事だけなので、送った文章の ID は読まない
                guard
                    let entryMethod = SyncedMeal.EntryMethod(
                        wireName: meal.entryMethod, sentTextId: nil)
                else {
                    throw SentSyncWrites.MalformedBodyError(reason: "知らない入口 \(meal.entryMethod)")
                }
                return .createMeal(
                    writeId: try uuid(write.id),
                    meal: SyncedMeal(
                        id: try uuid(meal.id),
                        eatenAt: Date(millisecondsSince1970: meal.eatenAt),
                        eatenUtcOffsetSeconds: meal.eatenAtUtcOffsetSeconds,
                        sentAt: Date(millisecondsSince1970: meal.sentAt),
                        sentTimeZone: try knownTimeZone(meal.sentTimeZone),
                        entryMethod: entryMethod,
                        photoIds: try meal.photos.map { try uuid($0.id) }
                    ))
            }
            if case .updateMeal(let write) = wire {
                return .updateMeal(
                    writeId: try uuid(write.id), mealId: try uuid(write.mealId),
                    eatenAt: Date(millisecondsSince1970: write.eatenAt))
            }
            if case .deleteMeal(let write) = wire {
                return .deleteMeal(writeId: try uuid(write.id), mealId: try uuid(write.mealId))
            }
            return nil
        }
    #endif
}

extension SyncChange {
    /// 知らない入口と、読めない ID・タイムゾーンは nil にする。送った文章の ID は文章の食事だけが持ち、古い版のアプリは読み飛ばす
    struct MealPayload: Decodable {
        let id: String
        let eatenAt: Int
        let eatenAtUtcOffsetSeconds: Int
        let sentAt: Int
        let sentTimeZone: String
        let entryMethod: String
        let sentTextId: String?
        let photos: [Photo]

        struct Photo: Decodable {
            let id: String
        }

        var syncedMeal: SyncedMeal? {
            let sentTextUUID = sentTextId.flatMap(UUID.init(uuidString:))
            guard let id = UUID(uuidString: id),
                let sentTimeZone = TimeZone(identifier: sentTimeZone),
                sentTextId == nil || sentTextUUID != nil,
                let entryMethod = SyncedMeal.EntryMethod(
                    wireName: entryMethod, sentTextId: sentTextUUID)
            else {
                return nil
            }
            let photoIds = photos.compactMap { UUID(uuidString: $0.id) }
            guard photoIds.count == photos.count else { return nil }
            return SyncedMeal(
                id: id,
                eatenAt: Date(millisecondsSince1970: eatenAt),
                eatenUtcOffsetSeconds: eatenAtUtcOffsetSeconds,
                sentAt: Date(millisecondsSince1970: sentAt),
                sentTimeZone: sentTimeZone,
                entryMethod: entryMethod,
                photoIds: photoIds
            )
        }
    }
}

#if DEBUG
    extension SyncChange.MealPayload: Encodable {
        fileprivate init(_ meal: SyncedMeal) {
            self.init(
                id: meal.id.canonicalString,
                eatenAt: meal.eatenAt.millisecondsSince1970,
                eatenAtUtcOffsetSeconds: meal.eatenUtcOffsetSeconds,
                sentAt: meal.sentAt.millisecondsSince1970,
                sentTimeZone: meal.sentTimeZone.identifier,
                entryMethod: meal.entryMethod.wireName,
                sentTextId: {
                    if case .written(let sentTextId) = meal.entryMethod {
                        sentTextId.canonicalString
                    } else {
                        nil
                    }
                }(),
                photos: meal.photoIds.map { .init(id: $0.canonicalString) }
            )
        }
    }
    extension SyncChange.MealPayload.Photo: Encodable {}
#endif
