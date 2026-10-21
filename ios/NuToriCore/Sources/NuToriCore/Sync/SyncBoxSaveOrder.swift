public import Foundation
import NuToriAPI

/// 送り待ちの箱が結果を当てる保存の順（ADR-0022）。順と分け方はここに1回だけ書き、箱（SwiftData とメモリ）は置き場の操作だけを渡す。
/// 1. 送り待ちに足すものとヘルスケアの同期の進み具合を、1つの保存で書く（どちらも無ければ保存しない）
/// 2. 種類の変更を、種類ごとに 100 件ずつに分けてキャッシュに当て、分けるたびに保存する。通し番号は最後の保存でだけ書く。
///    変更が無く通し番号だけがあれば、通し番号だけを1つの保存で書く
/// 3. 結果を受け取った送り待ちを、キャッシュのあとに1つの保存で消す（無ければ保存しない）
public enum SyncBoxSaveOrder {
    /// 1回の保存で当てる変更の数。メインのコンテキストを長く止めないよう、分けて保存する
    static let batchSize = 100

    /// - Parameters:
    ///   - savePending: 送り待ちに足し、ヘルスケアの同期の進み具合（nil は書かない）を書いて、送り待ちの置き場を1回保存する
    ///   - saveCache: 当てた変更の数と、この保存で書く同期の状態（nil は書かない）を受け取り、状態を書いてキャッシュの置き場を1回保存する
    ///   - removePending: 書き込みの ID の送り待ちを消し、送り待ちの置き場を1回保存する
    public static func apply<Cache>(
        _ result: SyncBoxResult,
        kinds: RecordKindRegistry<Cache>,
        cache: Cache,
        savePending: (_ enqueuing: [PendingEntry], _ healthSyncState: HealthSyncState?) throws ->
            Void,
        saveCache: (_ changeCount: Int, _ syncState: SyncState?) throws -> Void,
        removePending: (_ writeIds: Set<UUID>) throws -> Void
    ) throws {
        if !result.enqueuing.isEmpty || result.healthSyncState != nil {
            try savePending(result.enqueuing, result.healthSyncState)
        }
        // 結果を受け取った送り待ちを最後に消すのは、間で落ちても送り待ちが残り、次に送って同じ戻しに戻るため
        try applyToCache(result, kinds: kinds, cache: cache, saveCache: saveCache)
        if !result.resolvedWriteIds.isEmpty {
            try removePending(Set(result.resolvedWriteIds))
        }
    }

    /// 通し番号を最後の保存で書くのは、途中で落ちても、書いていない変更を追い越さないため
    private static func applyToCache<Cache>(
        _ result: SyncBoxResult,
        kinds: RecordKindRegistry<Cache>,
        cache: Cache,
        saveCache: (_ changeCount: Int, _ syncState: SyncState?) throws -> Void
    ) throws {
        // 知らない種類があれば、どの変更も当てる前に投げる
        var batches: [(kind: any RecordKind<Cache>, changes: [SyncChange])] = []
        for group in result.kindChanges {
            guard let kind = kinds.kind(named: group.kind) else {
                throw UnknownRecordKindError.notRegistered(group.kind)
            }
            for start in stride(from: 0, to: group.changes.count, by: batchSize) {
                let end = min(start + batchSize, group.changes.count)
                batches.append((kind, Array(group.changes[start..<end])))
            }
        }
        for (index, batch) in batches.enumerated() {
            try batch.kind.apply(batch.changes, to: cache)
            let isLast = index == batches.count - 1
            try saveCache(batch.changes.count, isLast ? result.syncState : nil)
        }
        if batches.isEmpty, let syncState = result.syncState {
            try saveCache(0, syncState)
        }
    }
}
