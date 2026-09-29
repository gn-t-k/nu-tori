public enum SyncChange: Sendable, Equatable {
    case weightRecord(SyncedWeightRecord)
    case accountSettings(SyncedAccountSettings)
    /// 知らない種類と読めない中身。サーバーが種類を足しても、古い版のアプリの同期が止まらないように、落とさずに持つ
    case unknown(kind: String)
}
