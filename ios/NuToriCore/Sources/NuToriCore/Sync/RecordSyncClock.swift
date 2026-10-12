public import Foundation

/// 同期の段取りが読む今と、待つこと
public struct RecordSyncClock: Sendable {
    /// 端末の今。初回の取得にかかった時間と、知らせを出すかを決める時刻まで待つ長さを測る
    public let now: @Sendable () -> Date
    /// 送ってからの経過を測る単調な時計。`now` は UI テストで止めるので、それで測ると1分の締め切りが来ない
    public let monotonicNow: @Sendable () -> ContinuousClock.Instant
    public let wait: @Sendable (Duration) async throws -> Void

    public init(
        now: @escaping @Sendable () -> Date,
        monotonicNow: @escaping @Sendable () -> ContinuousClock.Instant,
        wait: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.now = now
        self.monotonicNow = monotonicNow
        self.wait = wait
    }
}
