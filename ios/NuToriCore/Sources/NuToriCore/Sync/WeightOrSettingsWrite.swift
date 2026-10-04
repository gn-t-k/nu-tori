public import Foundation

/// 体重記録とアカウントの設定の書き込み。中身は、送り待ちの置き場の版 1 の JSON と同じ形（`PendingWriteContent`）
public enum WeightOrSettingsWrite: PendingWriteBody {
    case createWeightRecord(WeightRecord)
    case correctWeightRecord(WeightRecord)
    /// ヘルスケアで元のサンプルが消えた体重記録。消すかどうかはサーバーが決める
    case sourceDeletedWeightRecord(recordId: UUID)
    /// 記録が無くても直す書き込みで送る。サーバーが無ければ作る
    case updateAccountSettings(AccountSettings)

    public var kindName: RecordKindName {
        PendingWriteContent(self).kindName
    }

    public func content() throws -> Data {
        try JSONEncoder().encode(PendingWriteContent(self))
    }

    public init(kind: RecordKindName, content: Data) throws {
        let stored: PendingWriteContent
        do {
            stored = try JSONDecoder().decode(PendingWriteContent.self, from: content)
        } catch {
            throw PendingEntry.InvalidContentError(kind: kind)
        }
        self = try stored.write(kind: kind)
    }

    /// 版 1 の中身（種類の名前を持たない）から、種類の名前を読む。読めなければ nil
    public static func kindName(ofVersion1Content content: Data) -> RecordKindName? {
        try? JSONDecoder().decode(PendingWriteContent.self, from: content).kindName
    }
}
