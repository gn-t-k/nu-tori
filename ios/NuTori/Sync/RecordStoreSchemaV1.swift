import SwiftData

nonisolated enum RecordStoreSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [CachedWeightRecord.self, CachedPendingWrite.self, CachedSyncState.self]
    }
}

nonisolated enum RecordStoreSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            CachedWeightRecord.self, CachedPendingWrite.self, CachedSyncState.self,
            CachedHealthSyncState.self,
        ]
    }
}

nonisolated enum RecordStoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RecordStoreSchemaV1.self, RecordStoreSchemaV2.self]
    }

    static var stages: [MigrationStage] { [lightweightV1ToV2] }

    static let lightweightV1ToV2 = MigrationStage.lightweight(
        fromVersion: RecordStoreSchemaV1.self,
        toVersion: RecordStoreSchemaV2.self
    )

    /// 項目を移せない次の版は、この段を `stages` に足す。記録と同期の状態だけ消え、送り待ちは残る。
    /// 通し番号が無くなるので、次に開いたときに全部取り直す
    static func discardingCache<From: VersionedSchema, To: VersionedSchema>(
        from: From.Type,
        to: To.Type
    ) -> MigrationStage {
        .custom(
            fromVersion: from,
            toVersion: to,
            willMigrate: { context in
                try discardCacheKeepingPendingWrites(in: context)
            },
            didMigrate: nil
        )
    }

    static func discardCacheKeepingPendingWrites(in context: ModelContext) throws {
        try context.delete(model: CachedWeightRecord.self)
        try context.delete(model: CachedSyncState.self)
        try context.save()
    }
}
