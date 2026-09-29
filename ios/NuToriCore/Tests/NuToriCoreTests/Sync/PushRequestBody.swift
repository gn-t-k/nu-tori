import Foundation

struct PushRequestBody: Decodable {
    let writes: [Write]
    let isFinalBatch: Bool
    let clientState: ClientState

    struct Write: Decodable {
        let id: String
        let type: String
        private let payload: Payload

        var accountSettings: AccountSettings? {
            if case .accountSettings(let settings) = payload { settings } else { nil }
        }

        var weightRecordId: String? {
            if case .sourceDeletedWeightRecord(let recordId) = payload { recordId } else { nil }
        }

        struct AccountSettings: Decodable, Equatable {
            let id: String
            let sendsUsageData: Bool
        }

        private enum Payload {
            case weightRecord
            case accountSettings(AccountSettings)
            case sourceDeletedWeightRecord(String)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case type
            case accountSettings
            case weightRecordId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            switch type {
            case "update_account_settings":
                payload = .accountSettings(
                    try container.decode(AccountSettings.self, forKey: .accountSettings))
            case "source_deleted_weight_record":
                payload = .sourceDeletedWeightRecord(
                    try container.decode(String.self, forKey: .weightRecordId))
            default:
                payload = .weightRecord
            }
        }
    }

    struct ClientState: Decodable {
        let deviceId: String
        let timeZone: String
        let pendingWriteCount: Int
        let oldestPendingWriteAgeSeconds: Int?
        let pendingPhotoCount: Int
    }
}
