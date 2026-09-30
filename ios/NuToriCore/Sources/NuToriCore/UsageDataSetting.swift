/// 利用状況を送るか。観測の道具（PostHog）を始めてよいかも、ここで決める
public struct UsageDataSetting: Sendable, Equatable {
    /// アカウントの設定が無い（サーバーからも届いていない）ときは、サインインの同意で取っている既定のオン
    public let sendsUsageData: Bool
    public let hasCompletedInitialPull: Bool

    public init(accountSettings: AccountSettings?, hasCompletedInitialPull: Bool) {
        sendsUsageData = Self.sendsUsageData(accountSettings)
        self.hasCompletedInitialPull = hasCompletedInitialPull
    }

    public static func sendsUsageData(_ accountSettings: AccountSettings?) -> Bool {
        accountSettings?.sendsUsageData ?? true
    }

    /// 新しい端末では、ほかの端末で切ったオフが届くまで始めない
    public var canStartPostHog: Bool {
        sendsUsageData && hasCompletedInitialPull
    }
}
