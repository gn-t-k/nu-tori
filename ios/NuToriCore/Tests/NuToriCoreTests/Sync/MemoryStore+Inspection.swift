import Foundation
import NuToriCore
import NuToriTestSupport

extension MemoryStore {
    var records: [UUID: WeightRecord] { cache.records }
    var settings: AccountSettings? { cache.settings }

    /// 送り待ちを、体重記録とアカウントの設定の書き込みとして読んだもの
    var pending: [PendingWrite] {
        entries.compactMap { try? PendingWrite(entry: $0) }
    }
}
