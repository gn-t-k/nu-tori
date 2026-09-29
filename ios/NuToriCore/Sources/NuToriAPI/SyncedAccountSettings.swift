public import Foundation

/// サーバーと同期するアカウントの設定。送る書き込みと、取りに行って届く記録で同じ形
public struct SyncedAccountSettings: Sendable, Equatable {
    /// アカウント ID から名前空間を分けた UUID v5 で出す端末の ID
    public let id: UUID
    public let sendsUsageData: Bool

    public init(id: UUID, sendsUsageData: Bool) {
        self.id = id
        self.sendsUsageData = sendsUsageData
    }
}
