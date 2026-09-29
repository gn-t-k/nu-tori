/// 利用状況の送り先（PostHog）
public protocol AnalyticsSession: Sendable {
    /// 送り待ちの列を送り切る。呼び出し側がキャンセルしたら、すぐに戻る
    func flushPendingEvents() async
    func reset() async
}
