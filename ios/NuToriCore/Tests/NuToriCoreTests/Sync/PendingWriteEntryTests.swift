import Foundation
import NuToriCore
import Testing

@Suite("送り待ちの種類の名前と中身")
struct PendingWriteEntryTests {
    @Suite("体重記録の送り待ちを変換するとき")
    struct WeightRecordWrite {
        let write: PendingWrite

        init() throws {
            let previous = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            let corrected = WeightRecord(
                id: previous.id, kilograms: 72.0, instant: previous.instant,
                timeZone: previous.timeZone, inputSource: .manual, version: 2)
            write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .correctWeightRecord(corrected, previous: previous))
        }

        @Test("種類の名前を weight-record にし、直す前の値も中身に残すこと")
        func keepsPreviousInContent() throws {
            let entry = try write.entry()

            #expect(entry.kind == "weight-record")
            #expect(try PendingWrite(entry: entry) == write)
        }
    }

    @Suite("アカウントの設定の送り待ちを変換するとき")
    struct AccountSettingsWrite {
        let write: PendingWrite

        init() {
            write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .updateAccountSettings(.fixture(sendsUsageData: false)))
        }

        @Test("種類の名前を account-settings にすること")
        func namesKind() throws {
            let entry = try write.entry()

            #expect(entry.kind == "account-settings")
            #expect(try PendingWrite(entry: entry) == write)
        }
    }

    @Suite("送り待ちの置き場の版 1 の中身を読むとき")
    struct Version1Content {
        let content: Data
        let recordId: UUID

        init() {
            recordId = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!
            content = Data(
                """
                {"sourceDeleted":{"recordId":"\(recordId.uuidString)"}}
                """.utf8)
        }

        @Test("中身から種類の名前を読み、同じ書き込みとして解くこと")
        func readsKindAndOperation() throws {
            let writeId = UUID()
            let entry = PendingEntry(
                writeId: writeId, enqueuedAt: SyncEngine.fixtureNow,
                kind: try #require(PendingWrite.kindName(ofVersion1Content: content)),
                content: content)

            #expect(entry.kind == "weight-record")
            #expect(
                try PendingWrite(entry: entry).operation
                    == .sourceDeletedWeightRecord(recordId: recordId))
        }
    }

    @Suite("読めない中身のとき")
    struct InvalidContent {
        @Test("種類の名前を読めず、書き込みにも解けないこと")
        func failsToRead() {
            let content = Data("{}".utf8)
            let entry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow, kind: "meal", content: content)

            #expect(PendingWrite.kindName(ofVersion1Content: content) == nil)
            #expect(throws: PendingWrite.InvalidEntryError(kind: "meal")) {
                try PendingWrite(entry: entry)
            }
        }
    }
}
