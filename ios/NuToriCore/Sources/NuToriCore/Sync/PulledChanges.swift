public import Foundation

public struct PulledChanges: Sendable, Equatable {
    public let records: [WeightRecord]
    /// 削除の印が届いた記録の ID。置き場に無い ID は読み飛ばす（同じ削除の印は返し直されるため）
    public let removedRecordIds: [UUID]
    /// 記録と同じ保存で書く。通し番号だけが先に進んで記録が抜けないように
    public let state: SyncState

    public init(records: [WeightRecord], removedRecordIds: [UUID], state: SyncState) {
        self.records = records
        self.removedRecordIds = removedRecordIds
        self.state = state
    }
}
