import NuToriCore
import SwiftData

@testable import NuTori

extension SwiftDataWeightTrendCache {
    /// adapter のテストが、置き場に書けた値を読むための短い呼び方。
    /// 書いたコンテキストで読むと、手元の行がそのまま返り、置き場に書けた値を確かめられないので、保存して別のコンテキストで読む
    @MainActor func savedRecord() throws -> WeightTrend? {
        try context.save()
        return try SwiftDataWeightTrendCache(context: ModelContext(context.container)).read()
    }
}
