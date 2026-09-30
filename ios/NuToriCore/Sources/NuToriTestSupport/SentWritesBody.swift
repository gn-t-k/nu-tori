import Foundation

/// テストが読む、`POST /v1/sync/writes` で端末が送った本文
///
/// 知らない種類の書き込みを受けたら、読むところで投げてテストを落とす。
/// 書き込みの種類を足したら、ここの `Write` に足す
public struct SentWritesBody: Decodable, Equatable, Sendable {
    public let clientState: ClientState
    public let isFinalBatch: Bool
    public let writes: [Write]

    public init(json: String) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
    }

    public init(clientState: ClientState, isFinalBatch: Bool, writes: [Write]) {
        self.clientState = clientState
        self.isFinalBatch = isFinalBatch
        self.writes = writes
    }

    public struct ClientState: Decodable, Equatable, Sendable {
        public let deviceId: String
        public let timeZone: String
        public let appVersion: String
        public let osVersion: String
        public let pendingWriteCount: Int
        public let oldestPendingWriteAgeSeconds: Int?
        public let pendingPhotoCount: Int

        public init(
            deviceId: String,
            timeZone: String,
            appVersion: String,
            osVersion: String,
            pendingWriteCount: Int,
            oldestPendingWriteAgeSeconds: Int?,
            pendingPhotoCount: Int
        ) {
            self.deviceId = deviceId
            self.timeZone = timeZone
            self.appVersion = appVersion
            self.osVersion = osVersion
            self.pendingWriteCount = pendingWriteCount
            self.oldestPendingWriteAgeSeconds = oldestPendingWriteAgeSeconds
            self.pendingPhotoCount = pendingPhotoCount
        }
    }

    public enum Write: Decodable, Equatable, Sendable {
        case createWeightRecord(id: String, WeightRecord)
        case updateWeightRecord(id: String, WeightRecord)
        case sourceDeletedWeightRecord(id: String, weightRecordId: String)
        case updateAccountSettings(id: String, AccountSettings)

        public var id: String {
            switch self {
            case .createWeightRecord(let id, _), .updateWeightRecord(let id, _),
                .sourceDeletedWeightRecord(let id, _), .updateAccountSettings(let id, _):
                id
            }
        }

        /// 送った本文の `type` の値
        public var type: String {
            switch self {
            case .createWeightRecord: "create_weight_record"
            case .updateWeightRecord: "update_weight_record"
            case .sourceDeletedWeightRecord: "source_deleted_weight_record"
            case .updateAccountSettings: "update_account_settings"
            }
        }

        public var weightRecord: WeightRecord? {
            switch self {
            case .createWeightRecord(_, let record), .updateWeightRecord(_, let record): record
            case .sourceDeletedWeightRecord, .updateAccountSettings: nil
            }
        }

        public var weightRecordId: String? {
            if case .sourceDeletedWeightRecord(_, let weightRecordId) = self {
                weightRecordId
            } else {
                nil
            }
        }

        public var accountSettings: AccountSettings? {
            if case .updateAccountSettings(_, let settings) = self { settings } else { nil }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decode(String.self, forKey: .id)
            switch try container.decode(String.self, forKey: .type) {
            case "create_weight_record":
                self = .createWeightRecord(
                    id: id, try container.decode(WeightRecord.self, forKey: .weightRecord))
            case "update_weight_record":
                self = .updateWeightRecord(
                    id: id, try container.decode(WeightRecord.self, forKey: .weightRecord))
            case "source_deleted_weight_record":
                self = .sourceDeletedWeightRecord(
                    id: id,
                    weightRecordId: try container.decode(String.self, forKey: .weightRecordId))
            case "update_account_settings":
                self = .updateAccountSettings(
                    id: id, try container.decode(AccountSettings.self, forKey: .accountSettings))
            case let type:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container,
                    debugDescription:
                        "知らない種類の書き込み \(type) を送った。NuToriTestSupport の SentWritesBody.Write に足す")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case type
            case weightRecord
            case weightRecordId
            case accountSettings
        }
    }

    public struct AccountSettings: Decodable, Equatable, Sendable {
        public let id: String
        public let sendsUsageData: Bool

        public init(id: String, sendsUsageData: Bool) {
            self.id = id
            self.sendsUsageData = sendsUsageData
        }
    }

    public struct WeightRecord: Decodable, Equatable, Sendable {
        public let id: String
        public let weightKg: Double
        public let measuredAt: Int
        public let timeZone: String
        public let version: Int?
        public let imported: Imported?

        public init(
            id: String, weightKg: Double, measuredAt: Int, timeZone: String, version: Int?,
            imported: Imported?
        ) {
            self.id = id
            self.weightKg = weightKg
            self.measuredAt = measuredAt
            self.timeZone = timeZone
            self.version = version
            self.imported = imported
        }
    }

    public struct Imported: Decodable, Equatable, Sendable {
        public let sourceAppName: String
        public let sourceBundleId: String
        public let healthkitSampleUuid: String
        public let bodyFat: BodyFat?

        public init(
            sourceAppName: String, sourceBundleId: String, healthkitSampleUuid: String,
            bodyFat: BodyFat?
        ) {
            self.sourceAppName = sourceAppName
            self.sourceBundleId = sourceBundleId
            self.healthkitSampleUuid = healthkitSampleUuid
            self.bodyFat = bodyFat
        }
    }

    public struct BodyFat: Decodable, Equatable, Sendable {
        public let percentage: Double
        public let healthkitSampleUuid: String

        public init(percentage: Double, healthkitSampleUuid: String) {
            self.percentage = percentage
            self.healthkitSampleUuid = healthkitSampleUuid
        }
    }
}
