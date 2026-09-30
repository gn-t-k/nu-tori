import Foundation

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

        var type: String {
            switch payload {
            case .weightRecord(let type, _): type
            case .accountSettings: "update_account_settings"
            }
        }

        var weightRecord: WeightRecord? {
            guard case .weightRecord(_, let record) = payload else {
                return nil
            }
            return record
        }

        init(id: String, type: String, weightRecord: WeightRecord) {
            self.id = id
            payload = .weightRecord(type: type, record: weightRecord)
        }

        init(id: String, accountSettings: AccountSettings) {
            self.id = id
            payload = .accountSettings(accountSettings)
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "update_account_settings":
                payload = .accountSettings(
                    try container.decode(AccountSettings.self, forKey: .accountSettings))
            default:
                payload = .weightRecord(
                    type: type,
                    record: try container.decode(WeightRecord.self, forKey: .weightRecord))
            }
        }

        private let payload: Payload

        private enum Payload: Equatable {
            case weightRecord(type: String, record: WeightRecord)
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
