import Foundation

/// ID は record に無く、recordId から読む
struct UsualWeighingTimeWireCoding: RecordKindWireCoding {
    let kind = Components.Schemas.RecordKindName.usualWeighingTime

    var writes: (any RecordKindWriteWireCoding)? { nil }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            guard let id = UUID(uuidString: recordId),
                let payload = try? record.decoded(as: SyncChange.UsualWeighingTimePayload.self)
            else { return nil }
            return .usualWeighingTime(
                SyncedUsualWeighingTime(id: id, minuteOfDay: payload.minuteOfDay))
        case .deletion, .absence:
            return nil
        }
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .usualWeighingTime(let time) = change else { return nil }
            return .value(
                id: time.id,
                record: SyncChange.UsualWeighingTimePayload(minuteOfDay: time.minuteOfDay))
        }
    #endif
}

extension SyncChange {
    struct UsualWeighingTimePayload: Decodable {
        let minuteOfDay: Int
    }
}

#if DEBUG
    extension SyncChange.UsualWeighingTimePayload: Encodable {}
#endif
