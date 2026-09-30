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
        let pendingDirectory: URL
        let originalFiles: [String: Data]

        init() throws {
            directory = SwiftDataSyncStoreTests.makeDirectory()
            pendingDirectory = directory.appending(
                path: "PendingStore", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: pendingDirectory, withIntermediateDirectories: true)
            try SwiftDataSyncStoreTests.writeIncompatibleStore(
                entityName: "PendingWriteRow",
                at: pendingDirectory.appending(path: "PendingStore.store"))
            originalFiles = try SwiftDataSyncStoreTests.fileBytes(in: pendingDirectory)
        }

        @Test("元のファイルを日時つきの別名に移し、空で作り直し、対処した失敗として残すこと")
        func archivesAndRecreates() throws {
            let store = try SwiftDataSyncStore(directory: directory)

            #expect(store.takeRecoveries() == [.storeRecovery])
            let after = try SwiftDataSyncStoreTests.fileBytes(in: pendingDirectory)
            for (name, bytes) in originalFiles {
                let archived = after.filter { key, value in
                    key.hasPrefix(name + ".") && value == bytes
                }
                #expect(archived.count == 1)
            }
            #expect(after["PendingStore.store"] != originalFiles["PendingStore.store"])
        }
    }

    @Suite("それ以外の理由で開けないとき")
    @MainActor
    struct OtherOpenFailure {
        let directory: URL
        let pendingDirectory: URL
        let originalFiles: [String: Data]

        init() throws {
            directory = SwiftDataSyncStoreTests.makeDirectory()
            pendingDirectory = directory.appending(
                path: "PendingStore", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: pendingDirectory, withIntermediateDirectories: true)
            let store = pendingDirectory.appending(path: "PendingStore.store")
            try Data("not a database".utf8).write(to: store)
            try Data("shm".utf8).write(
                to: URL(filePath: store.path(percentEncoded: false) + "-shm"))
            try Data("wal".utf8).write(
                to: URL(filePath: store.path(percentEncoded: false) + "-wal"))
            originalFiles = try SwiftDataSyncStoreTests.fileBytes(in: pendingDirectory)
        }

        @Test("作り直さず、元のファイルが残ること")
        func keepsOriginalFiles() throws {
            #expect(throws: SwiftDataSyncStore.NotOpened.self) {
                _ = try SwiftDataSyncStore(directory: directory)
            }
            let after = try SwiftDataSyncStoreTests.fileBytes(in: pendingDirectory)
            #expect(after["PendingStore.store"] == originalFiles["PendingStore.store"])
            let archived = after.keys.filter { name in
                originalFiles.keys.contains { name.hasPrefix($0 + ".") }
            }
            #expect(archived.isEmpty)
        }
    }

    static func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "record-store-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    /// 今の形と合わない SQLite のファイル。`entityName` のモデルが1つだけあり、項目の型が違う
    static func writeIncompatibleStore(entityName: String, at url: URL) throws {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = entityName
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

    static func fileBytes(in directory: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        for url in urls {
            files[url.lastPathComponent] = try Data(contentsOf: url)
        }
        return files
    }
}
