import Foundation

/// 送り待ちの中身（送り待ちの置き場の版 1 の JSON と同じ形）。今の道の書き込みを持つ。
/// 直す書き込みは、以前は直す前の値（`previous`）も JSON に持っていた。今は持たないが、残った送り待ちの JSON にある
/// `previous` は、デコードのときに読み飛ばす（Codable は知らないキーを無視する）ので、置き場の版を上げずに読める
enum PendingWriteContent: Codable {
    case create(Record)
    case correct(record: Record)
    case sourceDeleted(recordId: UUID)
    case updateAccountSettings(id: UUID, sendsUsageData: Bool)

    init(_ operation: PendingWrite.Operation) {
        switch operation {
        case .createWeightRecord(let record):
            self = .create(Record(record))
        case .correctWeightRecord(let record):
            self = .correct(record: Record(record))
        case .sourceDeletedWeightRecord(let recordId):
            self = .sourceDeleted(recordId: recordId)
        case .updateAccountSettings(let settings):
            self = .updateAccountSettings(id: settings.id, sendsUsageData: settings.sendsUsageData)
        }
    }

    var kindName: String {
        switch self {
        case .create, .correct, .sourceDeleted: WeightRecordSyncing.kindName
        case .updateAccountSettings: AccountSettingsSyncKind.kindName
        }
    }

    func operation(kind: String) throws -> PendingWrite.Operation {
        switch self {
        case .create(let record):
            .createWeightRecord(try record.weightRecord(kind: kind))
        case .correct(let record):
            .correctWeightRecord(try record.weightRecord(kind: kind))
        case .sourceDeleted(let recordId):
            .sourceDeletedWeightRecord(recordId: recordId)
        case .updateAccountSettings(let id, let sendsUsageData):
            .updateAccountSettings(AccountSettings(id: id, sendsUsageData: sendsUsageData))
        }
    }

    struct Record: Codable {
        let id: UUID
        let kilograms: Double
        let measuredAt: Date
        let timeZoneIdentifier: String
        let version: Int
        let imported: StoredImported?

        struct StoredImported: Codable {
            let appName: String
            let bundleId: String
            let healthKitSampleId: UUID
            let bodyFat: StoredBodyFat?
        }

        struct StoredBodyFat: Codable {
            let percentage: Double
            let healthKitSampleId: UUID
        }

        init(_ record: WeightRecord) {
            id = record.id
            kilograms = record.kilograms
            measuredAt = record.instant
            timeZoneIdentifier = record.timeZone.identifier
            version = record.version
            switch record.inputSource {
            case .manual:
                imported = nil
            case .imported(let source):
                imported = StoredImported(
                    appName: source.appName,
                    bundleId: source.bundleId,
                    healthKitSampleId: source.healthKitSampleId,
                    bodyFat: source.bodyFat.map {
                        StoredBodyFat(
                            percentage: $0.percentage, healthKitSampleId: $0.healthKitSampleId)
                    }
                )
            }
        }

        func weightRecord(kind: String) throws -> WeightRecord {
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                throw PendingWrite.InvalidEntryError(kind: kind)
            }
            let inputSource: WeightRecord.InputSource =
                if let imported {
                    .imported(
                        WeightRecord.ImportedSource(
                            appName: imported.appName,
                            bundleId: imported.bundleId,
                            healthKitSampleId: imported.healthKitSampleId,
                            bodyFat: imported.bodyFat.map {
                                .init(
                                    percentage: $0.percentage,
                                    healthKitSampleId: $0.healthKitSampleId)
                            }
                        )
                    )
                } else {
                    .manual
                }
            return WeightRecord(
                id: id,
                kilograms: kilograms,
                instant: measuredAt,
                timeZone: timeZone,
                inputSource: inputSource,
                version: version
            )
        }
    }
}
