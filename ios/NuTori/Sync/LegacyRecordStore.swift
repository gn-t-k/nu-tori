import Foundation
import NuToriCore
import SwiftData

/// 置き場を分ける前の、1つの置き場（ADR-0022）。更新して最初に開いたときに、送り待ちとヘルスケアの同期の進み具合を送り待ちの置き場へ移し、この置き場を消す
nonisolated enum LegacyRecordStore {
    enum Outcome: Equatable {
        /// 今の置き場が無い（新しく入れたか、もう移した）
        case absent
        /// `droppedUnreadable`: 中身から種類の名前を読めない送り待ちを捨てた
        case carriedOver(droppedUnreadable: Bool)
        /// 移行できない形で開けず、送り待ちを捨てた
        case discarded
    }

    static func url(in directory: URL) -> URL {
        directory.appending(path: "RecordStore", directoryHint: .isDirectory)
            .appending(path: "RecordStore.store")
    }

    /// 送り待ちの置き場に移して保存したあとで、今の置き場を消す。
    /// 消す前に落ちても、次に開いたときにやり直せる（送り待ちは書き込みの ID で、進み具合は1件なので、上書きになる）。
    /// 移行できない形以外の理由で開けないときは、何も消さず `NotOpened` を投げる
    @MainActor static func carryOver(from url: URL, into pending: ModelContext) throws -> Outcome {
        guard StoreFiles.exists(at: url) else { return .absent }
        let contents: Contents
        do {
            contents = try read(at: url)
        } catch {
            guard
                StoreFiles.isUnmigratableShape(
                    error, schema: schema, plan: nil, name: storeName, at: url)
            else {
                throw SwiftDataSyncStore.NotOpened(cause: error)
            }
            try remove(at: url)
            return .discarded
        }
        try write(contents, into: pending)
        try remove(at: url)
        return .carriedOver(droppedUnreadable: contents.droppedUnreadable)
    }

    private struct Contents {
        let pendingWrites: [PendingWriteRow]
        let healthSyncState: HealthSyncStateRow?
        /// 中身から種類の名前を読めない送り待ちを、移さずに捨てた
        let droppedUnreadable: Bool
    }

    private static let storeName = "RecordStore"

    private static var schema: Schema {
        Schema(versionedSchema: LegacyRecordStoreSchemaV2.self)
    }

    private static func read(at url: URL) throws -> Contents {
        let container = try StoreFiles.container(
            schema: schema, plan: nil, name: storeName, at: url)
        let context = ModelContext(container)
        var writes: [PendingWriteRow] = []
        var droppedUnreadable = false
        for legacy in try context.fetch(
            FetchDescriptor<LegacyRecordStoreSchemaV2.CachedPendingWrite>())
        {
            guard let kind = PendingWriteContent.kindName(ofVersion1Content: legacy.operationJSON)
            else {
                droppedUnreadable = true
                continue
            }
            writes.append(
                PendingWriteRow(
                    writeId: legacy.writeId,
                    enqueuedAt: legacy.enqueuedAt,
                    kind: kind.rawValue,
                    content: legacy.operationJSON
                ))
        }
        let health = try context.fetch(
            FetchDescriptor<LegacyRecordStoreSchemaV2.CachedHealthSyncState>()
        ).first.map {
            HealthSyncStateRow(
                singletonKey: HealthSyncStateRow.onlyKey,
                anchorData: $0.anchorData,
                hasWrittenCachedManualRecords: $0.hasWrittenCachedManualRecords
            )
        }
        return Contents(
            pendingWrites: writes, healthSyncState: health, droppedUnreadable: droppedUnreadable)
    }

    @MainActor private static func write(_ contents: Contents, into context: ModelContext) throws {
        let existing = Set(try context.fetch(FetchDescriptor<PendingWriteRow>()).map(\.writeId))
        for row in contents.pendingWrites where !existing.contains(row.writeId) {
            context.insert(row)
        }
        if let health = contents.healthSyncState {
            if let current = try context.fetch(FetchDescriptor<HealthSyncStateRow>()).first {
                current.anchorData = health.anchorData
                current.hasWrittenCachedManualRecords = health.hasWrittenCachedManualRecords
            } else {
                context.insert(health)
            }
        }
        try context.save()
    }

    private static func remove(at url: URL) throws {
        do {
            try StoreFiles.remove(at: url)
        } catch {
            throw SwiftDataSyncStore.NotOpened(cause: error)
        }
    }
}
