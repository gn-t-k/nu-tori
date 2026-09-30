import Foundation
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

    /// 版 1 から移すときに、中身から種類の名前を読めなかった送り待ちの印。空の名前の種類は無いので、ほかと紛れない。
    /// 読めない行を種類の名前つきで残すと、送るたびに `UnknownRecordKindError` で同期が止まるので、開くときに `dropUnreadableRows` が捨てる
    static let unreadableKind = ""

    /// 中身から種類の名前を読めなかった送り待ちを捨てる。捨てたものがあれば true（呼び出し側が `storeRecovery` に残す）。
    /// 捨てた中身は記録に残さない（観測には数も送らない）
    @MainActor static func dropUnreadableRows(in context: ModelContext) throws -> Bool {
        let marker = unreadableKind
        let rows = try context.fetch(
            FetchDescriptor<PendingStoreSchemaV2.PendingWriteRow>(
                predicate: #Predicate { $0.kind == marker }))
        for row in rows {
            context.delete(row)
        }
        if !rows.isEmpty {
            try context.save()
        }
        return !rows.isEmpty
    }

    /// 版 1 の書き込みの中身（`operationJSON`）を `content` として引き継ぎ、種類の名前を中身から読んで書く。
    /// 中身は変えない。直す前の値（`previous`）が残っていても、中身を読むときに読み飛ばす（`PendingWriteContent`）。
    /// 中身から種類の名前を読めない行は `unreadableKind` を書き、開くときに捨てる
    private static var versionOneToTwo: MigrationStage {
        .custom(
            fromVersion: PendingStoreSchemaV1.self,
            toVersion: PendingStoreSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                let rows = try context.fetch(
                    FetchDescriptor<PendingStoreSchemaV2.PendingWriteRow>())
                for row in rows {
                    row.kind =
                        PendingWrite.kindName(ofVersion1Content: row.content)?.rawValue
                        ?? unreadableKind
                }
                try context.save()
            }
        )
    }
}
