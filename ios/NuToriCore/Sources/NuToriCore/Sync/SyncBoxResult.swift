public import Foundation

/// 箱に当てる結果。push の結果も、pull の頁も、ローカルでの記録の変更も、同じ形で当てる
public struct SyncBoxResult: Sendable, Equatable {
    /// 送り待ちに足すもの。キャッシュより先に保存する
    public let enqueuing: [PendingEntry]
    /// サーバーから結果を受け取った送り待ち。キャッシュに当てたあとに消す
    public let resolvedWriteIds: [UUID]
    /// 登録簿の種類に当てる変更と今の値
    public let kindChanges: [KindChanges]
    /// 登録簿に無い種類の巻き戻し（今の道。#182 で無くす）
    public let reversions: [RecordReversion]
    /// 登録簿に無い種類の取りに行った変更（今の道。#183 で無くす）。通し番号を持つので、あれば最後の保存で書く
    public let pulled: PulledChanges?

    public init(
        enqueuing: [PendingEntry] = [],
        resolvedWriteIds: [UUID] = [],
        kindChanges: [KindChanges] = [],
        reversions: [RecordReversion] = [],
        pulled: PulledChanges? = nil
    ) {
        self.enqueuing = enqueuing
        self.resolvedWriteIds = resolvedWriteIds
        self.kindChanges = kindChanges
        self.reversions = reversions
        self.pulled = pulled
    }
}
