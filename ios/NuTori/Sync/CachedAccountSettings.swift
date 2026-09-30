import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedAccountSettings {
    @Attribute(.unique) var singletonKey: String
    var settingsId: UUID
    var sendsUsageData: Bool

    init(_ settings: AccountSettings) {
        singletonKey = Self.onlyKey
        settingsId = settings.id
        sendsUsageData = settings.sendsUsageData
    }

    func accountSettings() -> AccountSettings {
        AccountSettings(id: settingsId, sendsUsageData: sendsUsageData)
    }

    func apply(_ settings: AccountSettings) {
        settingsId = settings.id
        sendsUsageData = settings.sendsUsageData
    }

    static let onlyKey = "account-settings"
}
