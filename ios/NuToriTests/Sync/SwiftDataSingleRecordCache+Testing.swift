import SwiftData

@testable import NuTori

extension SwiftDataSingleRecordCache {
    /// adapter のテストが、置き場に書けた値を読むための短い呼び方。
    /// 書いたコンテキストで読むと、手元の行がそのまま返り、置き場に書けた値を確かめられないので、保存して別のコンテキストで読む
    @MainActor func savedRecord() throws -> Row.Record? {
        try context.save()
        return try SwiftDataSingleRecordCache(context: ModelContext(context.container)).read()
    }
}
