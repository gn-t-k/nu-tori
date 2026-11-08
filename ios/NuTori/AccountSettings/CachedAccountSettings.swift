import Foundation
import NuToriCore
import SwiftData

/// アカウントの設定。アカウントに1つなので、行は1つだけ置く（`singletonKey` が重ならない）
@Model
nonisolated final class CachedAccountSettings {
    @Attribute(.unique) var singletonKey: String
    var settingsId: UUID
    var sendsUsageData: Bool

    init(_ settings: AccountSettings) {
        singletonKey = Self.onlyKey
        // 値は apply が入れる。SwiftData の行は、省けない欄に値を入れてからでないと apply を呼べないので、仮の値を入れておく
        settingsId = UUID()
        sendsUsageData = false
        apply(settings)
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
