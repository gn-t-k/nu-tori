public import Foundation

/// 箱に当てる結果。push の結果も、pull の頁も、ローカルでの記録の変更も、同じ形で当てる
public struct SyncBoxResult: Sendable, Equatable {
    /// 送り待ちに足すもの。キャッシュより先に保存する
    public let enqueuing: [PendingEntry]
    /// サーバーから結果を受け取った送り待ち。キャッシュに当てたあとに消す
    public let resolvedWriteIds: [UUID]
    /// 種類ごとに当てる変更と今の値。ローカルの記録の変更も、受け付けなかった書き込みの戻しも、この形で渡す
    public let kindChanges: [KindChanges]
    /// 書く同期の状態。通し番号を含むので、キャッシュへの最後の保存で書く（変更を追い越さない）
    public let syncState: SyncState?

    public init(
        enqueuing: [PendingEntry] = [],
        resolvedWriteIds: [UUID] = [],
        kindChanges: [KindChanges] = [],
        syncState: SyncState? = nil
    ) {
        self.enqueuing = enqueuing
        self.resolvedWriteIds = resolvedWriteIds
        self.kindChanges = kindChanges
        self.syncState = syncState
    }
}
