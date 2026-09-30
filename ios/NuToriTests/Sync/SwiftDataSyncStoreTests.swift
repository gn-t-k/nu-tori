import CoreData
import Foundation
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
