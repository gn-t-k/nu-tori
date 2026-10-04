import Foundation
import NuToriCore
import NuToriTestSupport

extension SyncBoxMock where Cache == RecordCacheMock {
    var records: [UUID: WeightRecord] { cache.records }
    var settings: AccountSettings? { cache.settings }

    /// 送り待ちのうち、体重記録の書き込みとして読めたもの
    var pendingWeightRecords: [PendingWeightRecordWrite] {
        entries.compactMap { try? PendingWeightRecordWrite(entry: $0) }
    }

    /// 送り待ちのうち、アカウントの設定の書き込みとして読めたもの
    var pendingAccountSettings: [PendingAccountSettingsWrite] {
        entries.compactMap { try? PendingAccountSettingsWrite(entry: $0) }
    }
}
