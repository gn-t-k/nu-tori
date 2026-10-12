import Foundation

/// アカウントの設定は消えないので、削除の印を持たない
struct AccountSettingsWireCoding: RecordKindWriteWireCoding {
    let kind = Components.Schemas.RecordKindName.accountSettings

    var writes: (any RecordKindWriteWireCoding)? { self }

    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?
    {
        switch form {
        case .value:
            (try? record.decoded(as: SyncChange.AccountSettingsPayload.self).syncedAccountSettings)
                .map { .accountSettings($0) }
        case .deletion, .absence: nil
        }
    }

    func wire(of write: SyncWrite) -> SyncWrite.Wire? {
        guard case .updateAccountSettings(let writeId, let settings) = write else { return nil }
        return .init(
            recordId: settings.id,
            body: .updateAccountSettings(
                .init(
                    id: writeId.canonicalString,
                    _type: .updateAccountSettings,
                    accountSettings: .init(
                        id: settings.id.canonicalString,
                        sendsUsageData: settings.sendsUsageData
                    )
                )
            ))
    }

    #if DEBUG
        func wire(of change: SyncChange) -> SyncChange.Wire? {
            guard case .accountSettings(let settings) = change else { return nil }
            return .value(
                id: settings.id,
                record: SyncChange.AccountSettingsPayload(
                    id: settings.id.canonicalString, sendsUsageData: settings.sendsUsageData))
        }

        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite? {
            guard case .updateAccountSettings(let write) = wire else { return nil }
            return .updateAccountSettings(
                writeId: try uuid(write.id),
                settings: SyncedAccountSettings(
                    id: try uuid(write.accountSettings.id),
                    sendsUsageData: write.accountSettings.sendsUsageData))
        }
    #endif
}

extension SyncChange {
    struct AccountSettingsPayload: Decodable {
        let id: String
        let sendsUsageData: Bool

        var syncedAccountSettings: SyncedAccountSettings? {
            UUID(uuidString: id).map {
                SyncedAccountSettings(id: $0, sendsUsageData: sendsUsageData)
            }
        }
    }
}

#if DEBUG
    extension SyncChange.AccountSettingsPayload: Encodable {}
#endif
