public import Foundation

public struct SyncedAccountSettings: Sendable, Equatable {
    public let id: UUID
    public let sendsUsageData: Bool

    public init(id: UUID, sendsUsageData: Bool) {
        self.id = id
        self.sendsUsageData = sendsUsageData
    }
}
