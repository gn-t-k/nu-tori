import NuToriCore
import SwiftData

/// 記録の種類の登録簿（アプリ）。名前の順に、手で1行ずつ書く。
/// 登録簿にある種類は送り待ちの箱の道で、無い種類（今はアカウントの設定）は今の道で当てる
nonisolated enum AppRecordKinds {
    static var registry: RecordKindRegistry<ModelContext> {
        RecordKindRegistry([WeightRecordKind()])
    }
}
