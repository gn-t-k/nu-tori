public import NuToriAPI

/// 受け付けなかった書き込み1件への、種類の扱い
public struct KindRejection: Sendable, Equatable {
    /// 画面に出す、受け付けなかった行。出さないときは nil
    public let rejectedWrite: RejectedWrite?
    /// 書き込む前の姿に戻す変更。その種類のキャッシュに、取りに行った変更と同じ形で当てる
    public let revertingChanges: [SyncChange]

    public init(rejectedWrite: RejectedWrite? = nil, revertingChanges: [SyncChange] = []) {
        self.rejectedWrite = rejectedWrite
        self.revertingChanges = revertingChanges
    }
}
