public import NuToriAPI

/// 受け付けなかった書き込み1件への、種類の扱い。
/// サーバーの今の値は、種類ごとの戻し方を持たずに、取りに行った変更と同じ道で当てる（`SyncEngine`）
public struct KindRejection: Sendable, Equatable {
    /// 画面に出す、受け付けなかった行。出さないときは nil
    public let rejectedWrite: RejectedWrite?
    /// サーバーに記録も削除の印も無いとき、この書き込みが指す記録をキャッシュから外す変更
    public let removingChanges: [SyncChange]

    public init(rejectedWrite: RejectedWrite? = nil, removingChanges: [SyncChange] = []) {
        self.rejectedWrite = rejectedWrite
        self.removingChanges = removingChanges
    }
}
