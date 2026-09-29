public struct SyncState: Sendable, Equatable {
    public let afterSequence: Int
    public let hasCompletedInitialPull: Bool
    public let readableKindsVersion: Int
    /// YYYY-MM-DD。サーバーで決まるまで nil
    public let startedOn: String?

    public init(
        afterSequence: Int,
        hasCompletedInitialPull: Bool,
        readableKindsVersion: Int,
        startedOn: String?
    ) {
        self.afterSequence = afterSequence
        self.hasCompletedInitialPull = hasCompletedInitialPull
        self.readableKindsVersion = readableKindsVersion
        self.startedOn = startedOn
    }
}
