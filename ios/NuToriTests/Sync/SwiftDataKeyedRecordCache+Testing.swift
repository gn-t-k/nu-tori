import SwiftData

@testable import NuTori

extension SwiftDataKeyedRecordCache {
    /// adapter のテストが、置き場に書けた値を読むための短い呼び方。
    /// 書いたコンテキストで読むと、手元の行がそのまま返り、置き場に書けた値を確かめられないので、保存して別のコンテキストで読む
    @MainActor func savedRecords() throws -> [Row.Record] {
        try context.save()
        return try SwiftDataKeyedRecordCache(context: ModelContext(context.container)).all()
    }
}
