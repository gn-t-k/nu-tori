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

    /// 保存は呼び出し側が行う
    static func write(_ settings: AccountSettings, in context: ModelContext) throws {
        if let existing = try current(in: context) {
            existing.apply(settings)
        } else {
            context.insert(CachedAccountSettings(settings))
        }
    }

    static func current(in context: ModelContext) throws -> CachedAccountSettings? {
        let key = onlyKey
        var descriptor = FetchDescriptor<CachedAccountSettings>(
            predicate: #Predicate { $0.singletonKey == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static let onlyKey = "account-settings"
}
