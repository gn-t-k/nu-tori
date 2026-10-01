import Foundation
import SwiftData

/// ヘルスケアに書いた料理の控え。書いた料理を書き直さず、消えた料理をヘルスケアから消すために持つ。
/// 料理の写しと同じキャッシュの置き場に持ち、置き場を作り直すと消える（取り直した料理を改めて書く）
@Model
nonisolated final class CachedHealthDishWrite {
    @Attribute(.unique) var dishId: UUID
    /// ヘルスケアに書いた料理の版
    var version: Int

    init(dishId: UUID, version: Int) {
        self.dishId = dishId
        self.version = version
    }
}

/// 控えの読み書き。保存は呼び出し側が行う
extension CachedHealthDishWrite {
    nonisolated static func find(dishId: UUID, in context: ModelContext) throws
        -> CachedHealthDishWrite?
    {
        var descriptor = FetchDescriptor<CachedHealthDishWrite>(
            predicate: #Predicate { $0.dishId == dishId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated static func mark(dishId: UUID, version: Int, in context: ModelContext) throws {
        if let existing = try find(dishId: dishId, in: context) {
            existing.version = version
        } else {
            context.insert(CachedHealthDishWrite(dishId: dishId, version: version))
        }
    }

    nonisolated static func unmark(dishId: UUID, in context: ModelContext) throws {
        if let existing = try find(dishId: dishId, in: context) {
            context.delete(existing)
        }
    }
}
