public import Foundation
public import NuToriCore
import Synchronization

/// メモリのキャッシュ。体重記録とアカウントの設定を持つ。登録簿の種類（`WeightRecordKindMock` など）が当てる。
/// 同期の働きの単体テストで、アプリの SwiftData のキャッシュの代わりに使う
public final class RecordCacheMock: Sendable {
    public init() {}

    public var records: [UUID: WeightRecord] {
        storage.withLock { $0.records }
    }

    public var settings: AccountSettings? {
        storage.withLock { $0.settings }
    }

    /// 名前の種類が当てられた変更の数。テスト用の種類（`note` など）が数えるのに使う
    public func appliedCount(of kind: String) -> Int {
        storage.withLock { $0.appliedCounts[kind, default: 0] }
    }

    public func upsert(_ record: WeightRecord) {
        storage.withLock { $0.records[record.id] = record }
    }

    public func remove(recordId: UUID) {
        storage.withLock { $0.records[recordId] = nil }
    }

    public func write(_ settings: AccountSettings) {
        storage.withLock { $0.settings = settings }
    }

    public func didApply(_ count: Int, forKind kind: String) {
        storage.withLock { $0.appliedCounts[kind, default: 0] += count }
    }

    public func clearRecords() {
        storage.withLock { $0.records = [:] }
    }

    public func clearSettings() {
        storage.withLock { $0.settings = nil }
    }

    public func clearApplied(forKind kind: String) {
        storage.withLock { $0.appliedCounts[kind] = nil }
    }

    private struct Storage {
        var records: [UUID: WeightRecord] = [:]
        var settings: AccountSettings?
        var appliedCounts: [String: Int] = [:]
    }

    private let storage = Mutex(Storage())
}
