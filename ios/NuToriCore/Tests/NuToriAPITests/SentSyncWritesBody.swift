import Foundation

/// 送った要求の本文を、型で読み戻して比べるためのもの
struct SentSyncWritesBody: Decodable, Equatable {
    let clientState: ClientState
    let isFinalBatch: Bool
    let writes: [Write]

    init(json: String) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }

    init(clientState: ClientState, isFinalBatch: Bool, writes: [Write]) {
        self.clientState = clientState
        self.isFinalBatch = isFinalBatch
        self.writes = writes
    }

    struct ClientState: Decodable, Equatable {
        let deviceId: String
        let timeZone: String
        let appVersion: String
        let osVersion: String
        let pendingWriteCount: Int
        let oldestPendingWriteAgeSeconds: Int?
        let pendingPhotoCount: Int
    }

    struct Write: Decodable, Equatable {
        let id: String
        let type: String
        let payload: Payload

        init(id: String, type: String, weightRecord: WeightRecord) {
            self.id = id
            self.type = type
            payload = .weightRecord(weightRecord)
        }

        init(id: String, type: String, accountSettings: AccountSettings) {
            self.id = id
            self.type = type
            payload = .accountSettings(accountSettings)
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            payload =
                switch type {
                case "update_account_settings":
                    .accountSettings(
                        try container.decode(AccountSettings.self, forKey: .accountSettings))
                default:
                    .weightRecord(try container.decode(WeightRecord.self, forKey: .weightRecord))
                }
        }

        var weightRecord: WeightRecord? {
            guard case .weightRecord(let record) = payload else {
                return nil
            }
            return record
        }

        enum Payload: Equatable {
            case weightRecord(WeightRecord)
            case accountSettings(AccountSettings)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case type
            case weightRecord
            case accountSettings
        }
    }

    struct AccountSettings: Decodable, Equatable {
        let id: String
        let sendsUsageData: Bool
    }

    struct WeightRecord: Decodable, Equatable {
        let id: String
        let weightKg: Double
        let measuredAt: Int
        let timeZone: String
        let version: Int?
        let imported: Imported?

    }

    struct Imported: Decodable, Equatable {
        let sourceAppName: String
        let sourceBundleId: String
        let healthkitSampleUuid: String
        let bodyFat: BodyFat?

    }

    struct BodyFat: Decodable, Equatable {
        let percentage: Double
        let healthkitSampleUuid: String
    }
}
