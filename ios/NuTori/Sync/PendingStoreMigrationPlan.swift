import NuToriCore
import SwiftData

/// 送り待ちの置き場だけが移行を持つ。キャッシュの置き場は持たない（ADR-0022）
nonisolated enum PendingStoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PendingStoreSchemaV1.self, PendingStoreSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [versionOneToTwo]
    }

    /// 版 1 の書き込みの中身（`operationJSON`）を `content` として引き継ぎ、種類の名前を中身から読んで書く。
    /// 中身は変えない。直す前の値（`previous`）が残っていても、中身を読むときに読み飛ばす（`PendingWriteContent`）
    private static var versionOneToTwo: MigrationStage {
        .custom(
            fromVersion: PendingStoreSchemaV1.self,
            toVersion: PendingStoreSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                let rows = try context.fetch(
                    FetchDescriptor<PendingStoreSchemaV2.PendingWriteRow>())
                for row in rows {
                    row.kind = PendingWrite.kindName(ofVersion1Content: row.content) ?? ""
                }
                try context.save()
            }
        )
    }
}
