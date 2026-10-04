public import Foundation

/// 体重記録とアカウントの設定の送り待ちの JSON の形（送り待ちの置き場の版 1 と同じ形）。
/// 版 1 は種類の名前を持たず、2つの種類が1つの形を分け合っていたので、今も `WeightRecordWrite` と `AccountSettingsWrite` がこの形を共有する。
/// 直す書き込みは、以前は直す前の値（`previous`）も JSON に持っていた。今は持たないが、残った送り待ちの JSON にある
/// `previous` は、デコードのときに読み飛ばす（Codable は知らないキーを無視する）ので、置き場の版を上げずに読める
public enum PendingWriteContent: Codable {
    case create(Record)
    case correct(record: Record)
    case sourceDeleted(recordId: UUID)
    case updateAccountSettings(id: UUID, sendsUsageData: Bool)

    /// 版 1 の中身（種類の名前を持たない）から、種類の名前を読む。読めなければ nil
    public static func kindName(ofVersion1Content content: Data) -> RecordKindName? {
        try? JSONDecoder().decode(PendingWriteContent.self, from: content).kindName
    }

    var kindName: RecordKindName {
        switch self {
        case .create, .correct, .sourceDeleted: WeightRecordSyncing.kindName
        case .updateAccountSettings: AccountSettingsSyncKind.kindName
        }
    }

    public struct Record: Codable {
        let id: UUID
        let kilograms: Double
        let measuredAt: Date
        let timeZoneIdentifier: String
        let version: Int
        let imported: StoredImported?

        public struct StoredImported: Codable {
            let appName: String
            let bundleId: String
            let healthKitSampleId: UUID
            let bodyFat: StoredBodyFat?
        }

        public struct StoredBodyFat: Codable {
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

        func weightRecord() -> WeightRecord? {
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                return nil
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
