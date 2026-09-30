import CoreData
import Foundation
import NuToriCore
import Testing

@testable import NuTori

@Suite("記録の置き場を開く")
struct SwiftDataSyncStoreTests {
    @Suite("移行の段で扱えない形のファイルのとき")
    @MainActor
    struct UnmigratableShape {
        let directory: URL
        let originalFiles: [String: Data]

        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(
                path: "record-store-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try Self.writeIncompatibleStore(at: directory.appending(path: "RecordStore.store"))
            originalFiles = try SwiftDataSyncStoreTests.fileBytes(in: directory)
        }

        @Test("元のファイルを日時つきの別名に移し、空で作り直すこと")
        func archivesAndRecreates() throws {
            _ = try SwiftDataSyncStore(directory: directory)

            let after = try SwiftDataSyncStoreTests.fileBytes(in: directory)
            for (name, bytes) in originalFiles {
                let archived = after.filter { key, value in
                    key.hasPrefix(name + ".") && value == bytes
                }
                #expect(archived.count == 1)
            }
            #expect(after["RecordStore.store"] != originalFiles["RecordStore.store"])
        }

        private static func writeIncompatibleStore(at url: URL) throws {
            let model = NSManagedObjectModel()
            let entity = NSEntityDescription()
            entity.name = "CachedWeightRecord"
            entity.managedObjectClassName = "CachedWeightRecord"
            let kilograms = NSAttributeDescription()
            kilograms.name = "kilograms"
            kilograms.attributeType = .stringAttributeType
            kilograms.isOptional = false
            entity.properties = [kilograms]
            model.entities = [entity]
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        }
    }

    @Suite("それ以外の理由で開けないとき")
    @MainActor
    struct OtherOpenFailure {
        let directory: URL
        let originalFiles: [String: Data]

        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(
                path: "record-store-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let store = directory.appending(path: "RecordStore.store")
            try Data("not a database".utf8).write(to: store)
            try Data("shm".utf8).write(
                to: URL(filePath: store.path(percentEncoded: false) + "-shm"))
            try Data("wal".utf8).write(
                to: URL(filePath: store.path(percentEncoded: false) + "-wal"))
            originalFiles = try SwiftDataSyncStoreTests.fileBytes(in: directory)
        }

        @Test("作り直さず、元のファイルが残ること")
        func keepsOriginalFiles() throws {
            #expect(throws: SwiftDataSyncStore.NotOpened.self) {
                _ = try SwiftDataSyncStore(directory: directory)
            }
            let after = try SwiftDataSyncStoreTests.fileBytes(in: directory)
            #expect(after["RecordStore.store"] == originalFiles["RecordStore.store"])
            let archived = after.keys.filter { name in
                originalFiles.keys.contains { name.hasPrefix($0 + ".") }
            }
            #expect(archived.isEmpty)
        }
    }

    private static func fileBytes(in directory: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        for url in urls {
            files[url.lastPathComponent] = try Data(contentsOf: url)
        }
        return files
    }
}

@Suite("アカウントの設定")
struct AccountSettingsStore {
    @Suite("保存したとき")
    @MainActor
    struct Saved {
        let store: SwiftDataSyncStore
        let settings: AccountSettings
        let write: PendingWrite

        init() throws {
            store = try SwiftDataSyncStore(inMemory: true)
            settings = AccountSettings(id: AccountSettingsStore.settingsId, sendsUsageData: false)
            write = PendingWrite(
                writeId: AccountSettingsStore.writeId,
                enqueuedAt: AccountSettingsStore.enqueuedAt,
                operation: .updateAccountSettings(settings)
            )
        }

        @Test("設定と送り待ちが残ること")
        func keepsSettingsAndPendingWrite() async throws {
            try await store.save(settings, enqueuing: write)
            #expect(try await store.accountSettings() == settings)
            #expect(try await store.pendingWritesOldestFirst() == [write])
        }
    }

    @Suite("設定が届いたあとに、設定の無い取得が来たとき")
    @MainActor
    struct ArrivedThenMissing {
        let store: SwiftDataSyncStore
        let arrived: AccountSettings
        let arrivedChanges: PulledChanges
        let missingChanges: PulledChanges

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let previous = AccountSettings(
                id: AccountSettingsStore.settingsId, sendsUsageData: false)
            try await store.save(
                previous,
                enqueuing: PendingWrite(
                    writeId: AccountSettingsStore.writeId,
                    enqueuedAt: AccountSettingsStore.enqueuedAt,
                    operation: .updateAccountSettings(previous)
                )
            )
            arrived = AccountSettings(id: AccountSettingsStore.settingsId, sendsUsageData: true)
            arrivedChanges = PulledChanges(
                records: [],
                removedRecordIds: [],
                accountSettings: arrived,
                state: SyncState(
                    afterSequence: 1,
                    hasCompletedInitialPull: true,
                    readableKindsVersion: 1,
                    startedOn: nil
                )
            )
            missingChanges = PulledChanges(
                records: [],
                removedRecordIds: [],
                accountSettings: nil,
                state: SyncState(
                    afterSequence: 2,
                    hasCompletedInitialPull: true,
                    readableKindsVersion: 1,
                    startedOn: nil
                )
            )
        }

        @Test("届いた設定が残ること")
        func keepsArrivedSettings() async throws {
            try await store.apply(arrivedChanges)
            try await store.apply(missingChanges)
            #expect(try await store.accountSettings() == arrived)
        }
    }

    @Suite("すべて消したとき")
    @MainActor
    struct Erased {
        let store: SwiftDataSyncStore

        init() async throws {
            store = try SwiftDataSyncStore(inMemory: true)
            let settings = AccountSettings(
                id: AccountSettingsStore.settingsId, sendsUsageData: false)
            try await store.save(
                settings,
                enqueuing: PendingWrite(
                    writeId: AccountSettingsStore.writeId,
                    enqueuedAt: AccountSettingsStore.enqueuedAt,
                    operation: .updateAccountSettings(settings)
                )
            )
        }

        @Test("設定も送り待ちも残らないこと")
        func clearsSettingsAndPendingWrites() async throws {
            try await store.eraseAll()
            #expect(try await store.accountSettings() == nil)
            #expect(try await store.pendingWritesOldestFirst().isEmpty)
        }
    }

    private static let settingsId = UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")!
    private static let writeId = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!
    private static let enqueuedAt = Date(timeIntervalSince1970: 1_700_000_000)
}
