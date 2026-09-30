import SwiftData

/// 送り待ちの置き場だけが移行を持つ。キャッシュの置き場は持たない（ADR-0022）
nonisolated enum PendingStoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PendingStoreSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
