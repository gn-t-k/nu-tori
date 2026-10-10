import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("送り待ちの種類の名前と中身")
struct PendingWriteEntryTests {
    @Suite("体重記録の送り待ちを変換するとき")
    struct WeightRecordConversion {
        let write: PendingWeightRecordWrite

        init() throws {
            let original = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            let corrected = WeightRecord(
                id: original.id, kilograms: 72.0, instant: original.instant,
                timeZone: original.timeZone, inputSource: .manual, version: 2)
            write = PendingWeightRecordWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .correctWeightRecord(corrected))
        }

        @Test("種類の名前を weight-record にし、直す前の値は中身に持たないこと")
        func hasNoPreviousInContent() throws {
            let entry = try write.entry()

            #expect(entry.kind == .weightRecord)
            #expect(try PendingWeightRecordWrite(entry: entry) == write)
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
            let write = try PendingWeightRecordWrite(entry: entry).write

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
                PendingWriteContent.kindName(ofVersion1Content: entry.content) == .weightRecord)
        }
    }

    @Suite("アカウントの設定の送り待ちを変換するとき")
    struct AccountSettingsConversion {
        let write: PendingAccountSettingsWrite

        init() {
            write = PendingAccountSettingsWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                write: .updateAccountSettings(.fixture(sendsUsageData: false)))
        }

        @Test("種類の名前を account-settings にすること")
        func namesKind() throws {
            let entry = try write.entry()

            #expect(entry.kind == .accountSettings)
            #expect(try PendingAccountSettingsWrite(entry: entry) == write)
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
                kind: try #require(PendingWriteContent.kindName(ofVersion1Content: content)),
                content: content)

            #expect(entry.kind == .weightRecord)
            #expect(
                try PendingWeightRecordWrite(entry: entry).write
                    == .sourceDeletedWeightRecord(recordId: recordId))
        }
    }

    @Suite("食事を直す書き込みを足す前の版が残した、食事の送り待ちを読むとき")
    struct LeftoverMealContent {
        let createEntry: PendingEntry
        let deleteEntry: PendingEntry
        let mealId: UUID
        let photoId: UUID

        init() throws {
            mealId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000f1"))
            photoId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1"))
            // 前の版が書いた形。時刻は 2001-01-01 からの秒数
            createEntry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow, kind: .meal,
                content: Data(
                    """
                    {"create":{"_0":{"id":"\(mealId.uuidString)","eatenAt":780000000,
                      "eatenUtcOffsetSeconds":32400,"sentAt":780000060,
                      "sentTimeZoneIdentifier":"Asia/Tokyo","entry":"captured",
                      "photoIds":["\(photoId.uuidString)"]}}}
                    """.utf8))
            deleteEntry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow, kind: .meal,
                content: Data(#"{"delete":{"mealId":"\#(mealId.uuidString)"}}"#.utf8))
        }

        @Test("作る書き込みとして読めること")
        func readsCreate() throws {
            let write = try PendingMealWrite(entry: createEntry).write

            #expect(
                write
                    == .create(
                        Meal(
                            id: mealId, eatenAt: Date(timeIntervalSinceReferenceDate: 780_000_000),
                            eatenUtcOffsetSeconds: 32_400,
                            sentAt: Date(timeIntervalSinceReferenceDate: 780_000_060),
                            sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                            entry: .captured, photoIds: [photoId])))
        }

        @Test("消す書き込みとして読めること")
        func readsDelete() throws {
            #expect(try PendingMealWrite(entry: deleteEntry).write == .delete(mealId: mealId))
        }
    }

    @Suite("料理と材料の送り待ちを変換するとき")
    struct DishAndIngredientConversion {
        let dishWrites: [PendingDishWrite]
        let ingredientWrite: PendingIngredientWrite

        init() throws {
            let dishId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000d1"))
            let ingredientId = try #require(
                UUID(uuidString: "00000000-0000-4000-8000-0000000000e1"))
            dishWrites = [
                PendingDishWrite(
                    enqueuedAt: SyncEngine.fixtureNow,
                    write: .create(
                        NewDish(id: dishId, mealId: UUID(), name: "味噌汁", positionInMeal: 2))),
                PendingDishWrite(
                    enqueuedAt: SyncEngine.fixtureNow,
                    write: .update(DishCorrection(id: dishId, name: "豚汁", quantity: nil))),
                PendingDishWrite(
                    enqueuedAt: SyncEngine.fixtureNow,
                    write: .update(
                        DishCorrection(
                            id: dishId, name: "豚汁",
                            quantity: .init(
                                value: 1.5,
                                proportionedIngredients: [
                                    .init(ingredientId: ingredientId, quantity: 120)
                                ])))),
                PendingDishWrite(enqueuedAt: SyncEngine.fixtureNow, write: .delete(dishId: dishId)),
            ]
            ingredientWrite = PendingIngredientWrite(
                enqueuedAt: SyncEngine.fixtureNow,
                write: .update(ingredientId: ingredientId, quantity: 150))
        }

        @Test("料理の種類の名前で入り、同じ書き込みとして読み戻せること")
        func roundTripsDishWrites() throws {
            let entries = try dishWrites.map { try $0.entry() }

            #expect(entries.map(\.kind) == [.dish, .dish, .dish, .dish])
            #expect(try entries.map { try PendingDishWrite(entry: $0) } == dishWrites)
        }

        @Test("材料の種類の名前で入り、同じ書き込みとして読み戻せること")
        func roundTripsIngredientWrite() throws {
            let entry = try ingredientWrite.entry()

            #expect(entry.kind == .ingredient)
            #expect(try PendingIngredientWrite(entry: entry) == ingredientWrite)
        }
    }

    @Suite("送った文章の送り待ちを変換するとき")
    struct SentTextConversion {
        let writes: [PendingSentTextWrite]

        init() throws {
            let sentText = SentText(
                id: try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")),
                body: "朝はパン、昼はうどん", sentAt: SyncEngine.fixtureNow,
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")))
            writes = [
                PendingSentTextWrite(enqueuedAt: SyncEngine.fixtureNow, write: .create(sentText)),
                PendingSentTextWrite(
                    enqueuedAt: SyncEngine.fixtureNow,
                    write: .resendAsConversation(sentTextId: sentText.id)),
                PendingSentTextWrite(
                    enqueuedAt: SyncEngine.fixtureNow, write: .resend(sentTextId: sentText.id)),
            ]
        }

        @Test("作る・会話として送り直す・送り直すのどれも、送った文章の種類の名前で入り、同じ書き込みとして読み戻せること")
        func roundTripsSentTextWrites() throws {
            let entries = try writes.map { try $0.entry() }

            #expect(entries.map(\.kind) == [.sentText, .sentText, .sentText])
            #expect(try entries.map { try PendingSentTextWrite(entry: $0) } == writes)
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

            #expect(PendingWriteContent.kindName(ofVersion1Content: content) == nil)
            #expect(throws: PendingEntry.InvalidContentError(kind: .weightRecord)) {
                try PendingWeightRecordWrite(entry: entry)
            }
        }
    }

    @Suite("ほかの種類の名前の送り待ちのとき")
    struct OtherKind {
        let entry: PendingEntry

        init() throws {
            let record = try WeightRecord.manual(
                72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            let content = try PendingWeightRecordWrite(
                enqueuedAt: SyncEngine.fixtureNow, write: .createWeightRecord(record)
            ).entry().content
            entry = PendingEntry(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow, kind: .accountSettings,
                content: content)
        }

        @Test("中身が読める形でも、種類の名前が違えば読まないこと")
        func rejectsByKindName() {
            #expect(throws: PendingEntry.InvalidContentError(kind: .accountSettings)) {
                try PendingWeightRecordWrite(entry: entry)
            }
        }
    }
}
