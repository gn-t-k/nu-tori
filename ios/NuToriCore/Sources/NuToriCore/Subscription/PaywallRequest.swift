/// 課金画面を開く求め。開いたところと、開いたときの状態と文を持つ
public struct PaywallRequest: Equatable, Sendable, Identifiable {
    public let entry: ClientUsageEvent.PaywallEntry
    public let standing: SubscriptionStanding
    public let content: PaywallContent

    public var id: ClientUsageEvent.PaywallEntry { entry }

    /// テストユーザーなら nil。文は開いたときの状態と今日で決め、開いているあいだに買って状態が変わっても描き替えない
    public init?(
        entry: ClientUsageEvent.PaywallEntry, standing: SubscriptionStanding, today: CalendarDay
    ) {
        guard let content = PaywallContent(standing: standing, today: today) else { return nil }
        self.entry = entry
        self.standing = standing
        self.content = content
    }
}
