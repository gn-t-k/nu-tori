import CoreData
import Foundation
import SwiftData

/// SwiftData の置き場のファイルを開く・退避する・消す道具
nonisolated enum StoreFiles {
    /// 移行できない形のファイルは日時つきの別名に移して、空で作り直す。それ以外の理由で開けないときは、ファイルを残して `NotOpened` を投げる
    static func openArchivingUnmigratable(
        schema: Schema,
        plan: (any SchemaMigrationPlan.Type)?,
        name: String,
        at url: URL
    ) throws -> (container: ModelContainer, archived: Bool) {
        do {
            return (try container(schema: schema, plan: plan, name: name, at: url), false)
        } catch {
            guard isUnmigratableShape(error, schema: schema, plan: plan, name: name, at: url)
            else {
                throw SwiftDataSyncStore.NotOpened(cause: error)
            }
            do {
                try archive(at: url)
            } catch {
                throw SwiftDataSyncStore.NotOpened(cause: error)
            }
            return (try container(schema: schema, plan: plan, name: name, at: url), true)
        }
    }

    static func container(
        schema: Schema,
        plan: (any SchemaMigrationPlan.Type)?,
        name: String,
        at url: URL
    ) throws -> ModelContainer {
        // ファイルの保護は指定しない。iOS の既定（初回のロック解除のあとは、バックグラウンド更新からも読める）
        try ModelContainer(
            for: schema,
            migrationPlan: plan,
            configurations: ModelConfiguration(
                name,
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        )
    }

    /// 移行できない形は SwiftDataError の backwardMigration・unknownSchema・unknownDataStoreSchema と、Core Data の NSPersistentStoreIncompatibleVersionHashError・NSMigrationError・NSMigrationMissingSourceModelError・NSMigrationMissingMappingModelError・NSInferredMappingModelError・NSStagedMigrationBackwardMigrationError。loadIssueModelContainer はコードを落とすので、版ハッシュが今のスキーマと違うときも同じとみなす
    static func isUnmigratableShape(
        _ error: any Error,
        schema: Schema,
        plan: (any SchemaMigrationPlan.Type)?,
        name: String,
        at url: URL
    ) -> Bool {
        if errorIndicatesMigrationMismatch(error) {
            return true
        }
        guard isLoadIssueModelContainer(error) else {
            return false
        }
        return versionHashesDifferFromCurrentSchema(schema: schema, plan: plan, name: name, at: url)
    }

    static func remove(at url: URL) throws {
        let manager = FileManager.default
        for suffix in ["-shm", "-wal", ""] {
            let path = url.path(percentEncoded: false) + suffix
            if manager.fileExists(atPath: path) {
                try manager.removeItem(atPath: path)
            }
        }
    }

    static func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private static func errorIndicatesMigrationMismatch(_ error: any Error) -> Bool {
        switch error {
        case SwiftDataError.backwardMigration, SwiftDataError.unknownSchema:
            return true
        default:
            break
        }
        if #available(iOS 27, *) {
            if case SwiftDataError.unknownDataStoreSchema = error {
                return true
            }
        }
        let nsError = error as NSError
        let migrationMismatchCodes: Set<Int> = [
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationError,
            NSMigrationMissingSourceModelError,
            NSMigrationMissingMappingModelError,
            NSInferredMappingModelError,
            NSStagedMigrationBackwardMigrationError,
        ]
        if nsError.domain == NSCocoaErrorDomain, migrationMismatchCodes.contains(nsError.code) {
            return true
        }
        if let underlying = underlyingError(of: nsError) {
            return errorIndicatesMigrationMismatch(underlying)
        }
        return false
    }

    private static func isLoadIssueModelContainer(_ error: any Error) -> Bool {
        switch error {
        case SwiftDataError.loadIssueModelContainer:
            return true
        default:
            return false
        }
    }

    private static func versionHashesDifferFromCurrentSchema(
        schema: Schema,
        plan: (any SchemaMigrationPlan.Type)?,
        name: String,
        at url: URL
    ) -> Bool {
        guard let onDisk = storeVersionHashes(at: url) else { return false }
        let reference = FileManager.default.temporaryDirectory.appending(
            path: "\(name)-schema-\(UUID().uuidString).store")
        defer { try? remove(at: reference) }
        do {
            _ = try container(schema: schema, plan: plan, name: name, at: reference)
        } catch {
            return false
        }
        guard let current = storeVersionHashes(at: reference) else { return false }
        return onDisk != current
    }

    private static func storeVersionHashes(at url: URL) -> [String: Data]? {
        guard
            let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: url),
            let hashes = versionHashes(in: metadata)
        else {
            return nil
        }
        return hashes
    }

    /// `NSError.userInfo` と永続ストアのメタデータは `[String: Any]` で、値の型はキーごとに Foundation が決めている。
    /// 型付きの取り出し口が無いので、`as?` で確かめて取り出す口をここに閉じ込める
    private static func underlyingError(of error: NSError) -> (any Error)? {
        error.userInfo[NSUnderlyingErrorKey] as? any Error
    }

    private static func versionHashes(in metadata: [String: Any]) -> [String: Data]? {
        metadata[NSStoreModelVersionHashesKey] as? [String: Data]
    }

    private static func archive(at url: URL) throws {
        // 退避したファイルの名前に付ける印で、記録の日付には使わないので、時計を通さない（置き場を開く前で、時計を受け取れない）
        let stamp = archiveStamp(Date())
        let manager = FileManager.default
        var moved: [(URL, URL)] = []
        do {
            for suffix in ["-shm", "-wal", ""] {
                let file = URL(filePath: url.path(percentEncoded: false) + suffix)
                let path = file.path(percentEncoded: false)
                guard manager.fileExists(atPath: path) else { continue }
                let destination = URL(filePath: path + "." + stamp)
                try manager.moveItem(at: file, to: destination)
                moved.append((file, destination))
            }
        } catch {
            for (file, destination) in moved.reversed() {
                try? manager.moveItem(at: destination, to: file)
            }
            throw error
        }
    }

    private static func archiveStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }
}
