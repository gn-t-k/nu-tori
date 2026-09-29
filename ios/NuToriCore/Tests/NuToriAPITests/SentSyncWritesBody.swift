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
        let weightRecord: WeightRecord?
        let accountSettings: AccountSettings?

        init(id: String, type: String, weightRecord: WeightRecord) {
            self.id = id
            self.type = type
            self.weightRecord = weightRecord
            accountSettings = nil
        }

        init(id: String, type: String, accountSettings: AccountSettings) {
            self.id = id
            self.type = type
            weightRecord = nil
            self.accountSettings = accountSettings
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
