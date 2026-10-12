public import NuToriAPI

/// 記録の種類（`CacheApplying`）の、登録簿の1行。箱のキャッシュ（`BoxCache`。アプリでは `ModelContext`、メモリの箱では `RecordCacheMock`）から、
/// その種類のキャッシュの口を取り出して当てる。種類ごとに書くのは、口の取り出し方の1行だけ
public struct PortedRecordKind<Syncing: CacheApplying, BoxCache>: RecordKind {
    /// - Parameter port: 箱のキャッシュから、この種類のキャッシュの口を取り出す
    public init(_ syncing: Syncing, port: @escaping @Sendable (BoxCache) -> Syncing.Cache) {
        self.syncing = syncing
        self.port = port
    }

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: BoxCache) throws {
        try syncing.apply(changes, to: port(cache))
    }

    public func erase(_ cache: BoxCache) throws {
        try syncing.erase(port(cache))
    }

    private let syncing: Syncing
    private let port: @Sendable (BoxCache) -> Syncing.Cache
}
