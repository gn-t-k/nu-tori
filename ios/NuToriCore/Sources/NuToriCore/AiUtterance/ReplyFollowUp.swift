public import Foundation

/// 文章を送ったあと（送り直したあとも）、応答を待つ送った文章があるあいだ、送ってから1分まで数秒おきに取りに行く（#26）。
/// 見守る要求がつながっている文章のためには取りに行かない（#29）。届け方の正本は同期で、見守る要求は足しただけの道
public struct ReplyFollowUp: Sendable {
    /// `sentAt` は送り終えた時点。`wait` は、次に取りに行くまで待つ
    public init(
        sentAt: ContinuousClock.Instant,
        now: @escaping @Sendable () -> ContinuousClock.Instant,
        wait: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.sentAt = sentAt
        self.now = now
        self.wait = wait
    }

    /// `awaiting` は応答を待つ送った文章（`SyncEngine.sentTextsAwaitingResponse()`）、`watching` は見守る要求がつながっている文章
    /// （`ReplyWatches.connectedSentTextIds`）。`sync` は、送り待ちを送って取りに行く1回。同期できなかった（nil）か、止まったら、続けない
    public func run(
        awaiting: () async throws -> Set<UUID>,
        watching: () async -> Set<UUID>,
        sync: () async throws -> SyncResult?
    ) async throws {
        let interval = Duration.seconds(3)
        let deadline = sentAt.advanced(by: .seconds(60))
        while try await !awaiting().isEmpty, now() < deadline {
            try await wait(interval)
            let unwatched = try await awaiting().subtracting(await watching())
            guard !unwatched.isEmpty else { continue }
            guard let result = try await sync(), result.ending == .finished else { return }
        }
    }

    private let sentAt: ContinuousClock.Instant
    private let now: @Sendable () -> ContinuousClock.Instant
    private let wait: @Sendable (Duration) async throws -> Void
}
