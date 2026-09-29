/// 利用状況を送るか。観測の道具（PostHog）を始めてよいかも、ここで決める
public struct UsageDataSetting: Sendable, Equatable {
    /// アカウントの設定が無い（サーバーからも届いていない）ときは、サインインの同意で取っている既定のオン
    public let sendsUsageData: Bool
    public let hasCompletedInitialPull: Bool

    public init(accountSettings: AccountSettings?, hasCompletedInitialPull: Bool) {
        sendsUsageData = accountSettings?.sendsUsageData ?? true
        self.hasCompletedInitialPull = hasCompletedInitialPull
    }

    /// 新しい端末では、ほかの端末で切ったオフが届くまで始めない
    public var canStartPostHog: Bool {
        sendsUsageData && hasCompletedInitialPull
    }
}
