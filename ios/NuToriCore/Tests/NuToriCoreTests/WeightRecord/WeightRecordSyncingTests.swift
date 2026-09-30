import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("体重記録の同期の形")
struct WeightRecordSyncingTests {
    @Suite("取りに行った変更を見分けるとき")
    struct Owning {
        let syncing = WeightRecordSyncing()

        @Test("体重記録と削除の印を受け持ち、アカウントの設定と知らない種類は受け持たないこと")
        func ownsOnlyWeightRecordChanges() throws {
            let record = SyncedWeightRecord(
                id: UUID(), weightKilograms: 72.4, measuredAt: Date(timeIntervalSince1970: 0),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), version: 1,
                imported: nil)

            #expect(syncing.owns(.weightRecord(record)))
            #expect(syncing.owns(.weightRecordDeletion(recordId: UUID())))
            #expect(
                !syncing.owns(
                    .accountSettings(SyncedAccountSettings(id: UUID(), sendsUsageData: true))))
            #expect(!syncing.owns(.unknown(kind: "note")))
        }
    }

    @Suite("取りに行った変更を今の値にするとき")
    struct ReadingCurrent {
        let syncing = WeightRecordSyncing()
        let arrived: SyncedWeightRecord
        let removedId: UUID

        init() throws {
            arrived = SyncedWeightRecord(
                id: UUID(), weightKilograms: 72.4, measuredAt: Date(timeIntervalSince1970: 100),
                timeZone: try #require(TimeZone(identifier: "Asia/Tokyo")), version: 3,
                imported: nil)
            removedId = UUID()
        }

        @Test("記録は今の値に、削除の印は ID にして、順に返すこと")
        func splitsRecordsAndRemovals() {
            let current = syncing.current(
                from: [
                    .weightRecord(arrived), .weightRecordDeletion(recordId: removedId),
                    .unknown(kind: "note"),
                ])

            #expect(current.records.map(\.id) == [arrived.id])
            #expect(current.records.map(\.version) == [3])
            #expect(current.removedRecordIds == [removedId])
        }
    }

    @Suite("送り待ちから送る書き込みを作るとき")
    struct BuildingWrite {
        let syncing = WeightRecordSyncing()
        let original: WeightRecord
        let corrected: WeightRecord

        init() throws {
            original = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            corrected = WeightRecord(
                id: original.id, kilograms: 72.0, instant: original.instant,
                timeZone: original.timeZone, inputSource: .manual, version: 2)
        }

        @Test("作る書き込みは、版を持たない新しい記録を送ること")
        func createsNewRecord() throws {
            let write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .createWeightRecord(original))

            let built = try syncing.syncWrite(for: write.entry())

            guard case .createWeightRecord(let writeId, let record) = built else {
                Issue.record("作る書き込みになっていない: \(built)")
                return
            }
            #expect(writeId == write.writeId)
            #expect(record.id == original.id)
            #expect(record.weightKilograms == 72.4)
        }

        @Test("直す書き込みは、直した値と版を送ること")
        func sendsCorrection() throws {
            let write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .correctWeightRecord(corrected))

            let built = try syncing.syncWrite(for: write.entry())

            guard case .updateWeightRecord(_, let correction) = built else {
                Issue.record("直す書き込みになっていない: \(built)")
                return
            }
            #expect(correction.weightKilograms == 72.0)
            #expect(correction.version == 2)
        }

        @Test("ヘルスケアで消えた記録の書き込みは、記録の ID を送ること")
        func sendsSourceDeletion() throws {
            let write = PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .sourceDeletedWeightRecord(recordId: original.id))

            let built = try syncing.syncWrite(for: write.entry())

            #expect(
                built
                    == .sourceDeletedWeightRecord(
                        writeId: write.writeId, weightRecordId: original.id))
        }

        @Test("アカウントの設定の送り待ちは、作れないこと")
        func rejectsAccountSettings() throws {
            let entry = try PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .updateAccountSettings(.fixture(sendsUsageData: true))
            ).entry()

            #expect(throws: PendingWrite.InvalidEntryError(kind: "account-settings")) {
                try syncing.syncWrite(for: entry)
            }
        }
    }

    @Suite("受け付けなかった書き込みを扱うとき")
    struct Rejecting {
        let syncing = WeightRecordSyncing()
        let corrected: WeightRecord
        let entry: PendingEntry

        init() throws {
            corrected = try .manual(
                72.0, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo", version: 2)
            entry = try PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .correctWeightRecord(corrected)
            ).entry()
        }

        @Test("サーバーに値があれば、値のある行にし、キャッシュから外す変更は返さないこと")
        func serverValue() throws {
            let server = SyncedWeightRecord(
                id: corrected.id, weightKilograms: 71.0, measuredAt: corrected.instant,
                timeZone: corrected.timeZone, version: 1, imported: nil)

            let rejection = try syncing.rejection(
                of: entry, reason: .versionTooLow, current: .value(.weightRecord(server)))

            #expect(rejection.rejectedWrite?.serverHasValue == true)
            #expect(rejection.rejectedWrite?.record == corrected)
        }

        @Test("サーバーの記録が削除の印なら、値の無い行にすること")
        func serverDeleted() throws {
            let rejection = try syncing.rejection(
                of: entry, reason: .versionTooLow,
                current: .deleted(.weightRecordDeletion(recordId: corrected.id)))

            #expect(rejection.rejectedWrite?.serverHasValue == false)
        }

        @Test("サーバーに無ければ、値の無い行にし、端末の記録を外す変更を返すこと")
        func serverAbsent() throws {
            let rejection = try syncing.rejection(
                of: entry, reason: .recordNotFound, current: .absent)

            #expect(rejection.rejectedWrite?.serverHasValue == false)
            #expect(rejection.removingChanges == [.weightRecordDeletion(recordId: corrected.id)])
        }

        @Test("元のサンプルが消えた書き込みは、行も外す変更も返さないこと")
        func sourceDeleted() throws {
            let sourceDeleted = try PendingWrite(
                writeId: UUID(), enqueuedAt: SyncEngine.fixtureNow,
                operation: .sourceDeletedWeightRecord(recordId: corrected.id)
            ).entry()

            let rejection = try syncing.rejection(
                of: sourceDeleted, reason: .recordNotFound, current: .absent)

            #expect(rejection == KindRejection())
        }
    }
}
