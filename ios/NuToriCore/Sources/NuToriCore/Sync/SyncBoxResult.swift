public import Foundation

/// 箱に当てる結果。push の結果も、pull の頁も、ローカルでの記録の変更も、ヘルスケアの取り込みも、同じ形で当てる
public struct SyncBoxResult: Sendable, Equatable {
    /// 送り待ちに足すもの。キャッシュより先に保存する
    public let enqueuing: [PendingEntry]
    /// サーバーから結果を受け取った送り待ち。キャッシュに当てたあとに消す
    public let resolvedWriteIds: [UUID]
    /// 種類ごとに当てる変更と今の値。ローカルの記録の変更も、受け付けなかった書き込みの戻しも、この形で渡す
    public let kindChanges: [KindChanges]
    /// 書く同期の状態。通し番号を含むので、キャッシュへの最後の保存で書く（変更を追い越さない）
    public let syncState: SyncState?
    /// 書くヘルスケアの同期の進み具合。送り待ちと同じ保存で書く。分かれて残ると、送り忘れるか、同じ変化を次に取りこぼす
    public let healthSyncState: HealthSyncState?

    public init(
        enqueuing: [PendingEntry] = [],
        resolvedWriteIds: [UUID] = [],
        kindChanges: [KindChanges] = [],
        syncState: SyncState? = nil,
        healthSyncState: HealthSyncState? = nil
    ) {
        self.enqueuing = enqueuing
        self.resolvedWriteIds = resolvedWriteIds
        self.kindChanges = kindChanges
        self.syncState = syncState
        self.healthSyncState = healthSyncState
    }
}
