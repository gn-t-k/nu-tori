import Foundation
import NuToriCore
import Testing

@Suite("送り待ちの種類の名前と中身")
struct PendingWriteEntryTests {
    @Suite("体重記録の送り待ちを変換するとき")
    struct WeightRecordWrite {
        let write: PendingWrite

        init() throws {
            let original = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            let corrected = WeightRecord(
                id: original.id, kilograms: 72.0, instant: original.instant,
                timeZone: original.timeZone, inputSource: .manual, version: 2)
            write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .correctWeightRecord(corrected))
        }

        @Test("種類の名前を weight-record にし、直す前の値は中身に持たないこと")
        func hasNoPreviousInContent() throws {
            let entry = try write.entry()

            #expect(entry.kind == .weightRecord)
            #expect(try PendingWrite(entry: entry) == write)
            #expect(!String(decoding: entry.content, as: UTF8.self).contains("previous"))
        }
    }

    @Suite("直す前の値（previous）を持つ、残った送り待ちの中身を読むとき")
    struct LeftoverContentWithPrevious {
        let entry: PendingEntry
        let recordId: UUID

        init() {
            recordId = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!
            // 以前の版が書いた形。measuredAt は 2001-01-01 からの秒数
            let content = Data(
                """
                {"correct":{
                  "record":{"id":"\(recordId.uuidString)","kilograms":72,"measuredAt":780000000,
                    "timeZoneIdentifier":"Asia/Tokyo","version":2},
                  "previous":{"id":"\(recordId.uuidString)","kilograms":71,"measuredAt":780000000,
                    "timeZoneIdentifier":"Asia/Tokyo","version":1}}}
                """.utf8)
            entry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                kind: .weightRecord, content: content)
        }

        @Test("直す前の値は読み飛ばし、直した値の書き込みとして読めること")
        func readsAsCorrection() throws {
            let write = try PendingWrite(entry: entry).write

            guard case .correctWeightRecord(let record) = write else {
                Issue.record("直す書き込みになっていない: \(write)")
                return
            }
            #expect(record.id == recordId)
            #expect(record.kilograms == 72)
            #expect(record.version == 2)
        }

        @Test("種類の名前も読めること")
        func readsKindName() {
            #expect(
                WeightOrSettingsWrite.kindName(ofVersion1Content: entry.content) == .weightRecord)
        }
    }

    @Suite("アカウントの設定の送り待ちを変換するとき")
    struct AccountSettingsWrite {
        let write: PendingWrite

        init() {
            write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .updateAccountSettings(.fixture(sendsUsageData: false)))
        }

        @Test("種類の名前を account-settings にすること")
        func namesKind() throws {
            let entry = try write.entry()

            #expect(entry.kind == .accountSettings)
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
                kind: try #require(WeightOrSettingsWrite.kindName(ofVersion1Content: content)),
                content: content)

            #expect(entry.kind == .weightRecord)
            #expect(
                try PendingWrite(entry: entry).write
                    == .sourceDeletedWeightRecord(recordId: recordId))
        }
    }

    @Suite("読めない中身のとき")
    struct InvalidContent {
        @Test("種類の名前を読めず、書き込みにも解けないこと")
        func failsToRead() {
            let content = Data("{}".utf8)
            let entry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow, kind: .weightRecord,
                content: content)

            #expect(WeightOrSettingsWrite.kindName(ofVersion1Content: content) == nil)
            #expect(throws: PendingEntry.InvalidContentError(kind: .weightRecord)) {
                try PendingWrite(entry: entry)
            }
        }
    }
}
