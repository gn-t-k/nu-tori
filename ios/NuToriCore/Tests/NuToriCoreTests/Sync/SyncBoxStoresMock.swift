import Foundation
import NuToriCore

/// 送り待ちの箱の置き場の操作（`SyncBoxSaveOrder.apply` に渡す閉包）の差し替え。保存を呼ばれた順に記録する
final class SyncBoxStoresMock {
    /// 1回の保存
    enum Save: Equatable {
        /// 送り待ちの置き場への保存。足した送り待ちと、書いたヘルスケアの同期の進み具合
        case pending(enqueued: [PendingEntry], healthSyncState: HealthSyncState?)
        /// キャッシュの置き場への保存。当てた変更の数と、この保存で書いた通し番号
        case cache(changes: Int, afterSequence: Int?)
        /// 結果を受け取った送り待ちを消す保存
        case removingPending(writeIds: Set<UUID>)
    }

    struct Failure: Error, Equatable {}

    private(set) var saves: [Save] = []

    static func ok() -> SyncBoxStoresMock {
        SyncBoxStoresMock(cacheSaveFailure: nil)
    }

    /// キャッシュの置き場への保存だけが、この失敗で投げる
    static func error(_ failure: Failure) -> SyncBoxStoresMock {
        SyncBoxStoresMock(cacheSaveFailure: failure)
    }

    func savePending(_ enqueuing: [PendingEntry], _ healthSyncState: HealthSyncState?) {
        saves.append(.pending(enqueued: enqueuing, healthSyncState: healthSyncState))
    }

    func saveCache(_ changeCount: Int, _ syncState: SyncState?) throws {
        if let cacheSaveFailure { throw cacheSaveFailure }
        saves.append(.cache(changes: changeCount, afterSequence: syncState?.afterSequence))
    }

    func removePending(_ writeIds: Set<UUID>) {
        saves.append(.removingPending(writeIds: writeIds))
    }

    private init(cacheSaveFailure: Failure?) {
        self.cacheSaveFailure = cacheSaveFailure
    }

    private let cacheSaveFailure: Failure?
}
