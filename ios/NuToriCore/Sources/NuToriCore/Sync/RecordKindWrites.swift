public import NuToriAPI

/// 端末が書く記録の種類の、送り待ちを送るところ。サーバーだけが書く種類は持たない（`SyncedRecordKind.writes`）
public protocol RecordKindWrites: Sendable {
    /// 送り待ちの中身から、サーバーに送る書き込みを作る
    func syncWrite(for entry: PendingEntry) throws -> SyncWrite

    /// 送り待ちの書き込みが、届くまで薄く描く記録（まだ届いていない記録。`UndeliveredRecords`）。
    /// 読めない中身と、薄く描く記録を持たない書き込み（消す書き込みなど）は空
    func undeliveredRecords(of entry: PendingEntry) -> [UndeliveredRecords.Record]

    /// サーバーが受け付けなかった書き込みの扱い。画面に出す行と、サーバーに記録が無いときにキャッシュから外す変更を返す。
    /// 値と削除の印は、同期の働きが取りに行った変更と同じ道で当てるので、ここでは戻さない。
    /// `current` は、その記録のサーバーの今の値。読めなかったときは nil。
    /// `shown` は、サーバーの今の値を当てる前のキャッシュの記録（行に出す、端末で見せていた名前と時刻）
    func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        current: SyncWriteResult.Current?,
        shown: ShownRecords
    ) throws -> KindRejection
}
