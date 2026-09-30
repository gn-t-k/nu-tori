import Foundation

struct PushRequestBody: Decodable {
    let writes: [Write]
    let isFinalBatch: Bool
    let clientState: ClientState

    struct Write: Decodable {
        let id: String

        var type: String {
            switch payload {
            case .weightRecord(let type): type
            case .accountSettings: "update_account_settings"
            case .sourceDeletedWeightRecord: "source_deleted_weight_record"
            }
        }

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

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            switch try container.decode(String.self, forKey: .type) {
            case "update_account_settings":
                payload = .accountSettings(
                    try container.decode(AccountSettings.self, forKey: .accountSettings))
            case "source_deleted_weight_record":
                payload = .sourceDeletedWeightRecord(
                    recordId: try container.decode(String.self, forKey: .weightRecordId))
            case let type:
                payload = .weightRecord(type: type)
            }
        }

        private let payload: Payload

        private enum Payload {
            case weightRecord(type: String)
            case accountSettings(AccountSettings)
            case sourceDeletedWeightRecord(recordId: String)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case type
            case accountSettings
            case weightRecordId
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
