public import Foundation
public import NuToriAPI

/// 記録の種類の、キャッシュの型に依らない部分。同期の働き（`SyncEngine`）が見る
public protocol SyncedRecordKind: Sendable {
    /// 登録簿の名前。送り待ちの種類の名前と同じ
    var name: String { get }

    /// 取りに行った変更が、この種類のものか
    func owns(_ change: SyncChange) -> Bool

    /// 送り待ちの中身から、サーバーに送る書き込みを作る
    func syncWrite(for entry: PendingEntry) throws -> SyncWrite

    /// サーバーが受け付けなかった書き込みの扱い。画面に出す行と、キャッシュを戻す変更を返す。
    /// 同じ記録を戻すのは1回だけにするため、戻した記録の ID を `revertedRecordIds` で持ち回る（今の値を当てる形に替える #185 まで）
    func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        revertedRecordIds: inout Set<UUID>
    ) throws -> KindRejection
}
