/// 食事や写真、料理を足す・名前を直す書き込みを送ったあと、推定中の食事か料理があるあいだ、送ってから1分まで数秒おきに取りに行く。
/// そのあとは、ふだんの時機（開いたとき、電波が戻ったとき、バックグラウンド更新）にだけ取りに行く。翌日に推定の食事と料理は待たない
public struct EstimationFollowUp: Sendable {
    /// `sentAt` は送り終えた時点、`now` は今の時点。`wait` は、次に取りに行くまで待つ
    public init(
        sentAt: ContinuousClock.Instant,
        cache: any RecordCacheReading,
        now: @escaping @Sendable () -> ContinuousClock.Instant,
        wait: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.sentAt = sentAt
        self.cache = cache
        self.now = now
        self.wait = wait
    }

    /// `sync` は、送り待ちを送って取りに行く1回。同期できなかった（nil）か、止まったら、続けない
    public func run(sync: () async throws -> SyncResult?) async throws {
        let interval = Duration.seconds(3)
        let deadline = sentAt.advanced(by: .seconds(60))
        while try await hasEstimating(), now() < deadline {
            try await wait(interval)
            guard let result = try await sync(), result.ending == .finished else { return }
        }
    }

    private let sentAt: ContinuousClock.Instant
    private let cache: any RecordCacheReading
    private let now: @Sendable () -> ContinuousClock.Instant
    private let wait: @Sendable (Duration) async throws -> Void

    private func hasEstimating() async throws -> Bool {
        if try await cache.mealEstimationStatuses().values.contains(.estimating) {
            return true
        }
        return try await cache.dishEstimationStatuses().values.contains(.estimating)
    }
}
