/// ヘルスケアの取り込みが使う置き場の口。進み具合は送り待ちの置き場に持つ
public protocol HealthSyncStoring: Sendable {
    func healthSyncState() async throws -> HealthSyncState
    func saveHealthSyncState(_ state: HealthSyncState) async throws

    /// 記録と送り待ちとアンカーが分かれて残ると、送り忘れるか、同じ変化を次に取りこぼす
    func applyHealthImport(_ batch: HealthImportBatch) async throws
}
