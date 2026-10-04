import Foundation
import NuToriTestSupport
import OpenAPIRuntime
import Testing

@testable import NuToriAPI

@Suite("偽の同期サーバー")
struct FakeSyncServerTests {
    static let startedOn = "2026-01-01"
    static let weightRecord = Components.Schemas.RecordKindName.weightRecord.rawValue

    static func client(_ scenario: FakeSyncServer.Scenario) -> NuToriAPIClient {
        NuToriAPIClient(
            serverURL: URL(string: "https://api.example")!,
            transport: FakeSyncServer(scenario),
            appBuildGate: .sample,
            sessionToken: { FakeSyncServer.sessionToken }
        )
    }

    @Suite("初めに記録を置いたとき")
    struct InitialRecords {
        let record: SyncedWeightRecord
        let client: NuToriAPIClient

        init() {
            record = .fixture(version: 1)
            client = FakeSyncServerTests.client(
                .init(records: [.weightRecord(record)], startedOn: FakeSyncServerTests.startedOn))
        }

        @Test("置いた記録を、通し番号を振って続きなしで返すこと")
        func returnsInitialRecords() async throws {
            let result = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())

            #expect(
                result
                    == .pulled(
                        SyncChangesPage(
                            changes: [.weightRecord(record)], hasMore: false, nextAfterSequence: 1,
                            startedOn: FakeSyncServerTests.startedOn)))
        }

        @Test("返した通し番号より後を取りに行くと、変更を返さないこと")
        func returnsNothingAfterLastSequence() async throws {
            let result = try await client.pullSyncChanges(afterSequence: 1, clientState: .fixture())

            #expect(
                result
                    == .pulled(
                        SyncChangesPage(
                            changes: [], hasMore: false, nextAfterSequence: 1,
                            startedOn: FakeSyncServerTests.startedOn)))
        }
    }

    @Suite("書き込みを受け付ける方針のとき")
    struct Applying {
        let createWriteId: UUID
        let updateWriteId: UUID
        let client: NuToriAPIClient

        init() throws {
            createWriteId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
            updateWriteId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a2"))
            client = FakeSyncServerTests.client(
                .init(records: [], startedOn: FakeSyncServerTests.startedOn))
        }

        @Test("受け付けたと返し、同じ記録を作って直した書き込みの、直した値を次の取得で返すこと")
        func appliesWrites() async throws {
            let pushed = try await client.pushSyncWrites(
                [
                    .createWeightRecord(writeId: createWriteId, record: .fixture()),
                    .updateWeightRecord(writeId: updateWriteId, correction: .fixture()),
                ],
                isFinalBatch: true, clientState: .fixture())
            let pulled = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())

            #expect(
                pushed
                    == .pushed([
                        SyncWriteResult(writeId: createWriteId, outcome: .applied, current: nil),
                        SyncWriteResult(writeId: updateWriteId, outcome: .applied, current: nil),
                    ]))
            #expect(
                pulled
                    == .pulled(
                        SyncChangesPage(
                            changes: [.weightRecord(.fixture(version: 2))], hasMore: false,
                            nextAfterSequence: 2, startedOn: FakeSyncServerTests.startedOn)))
        }
    }

    @Suite("記録の種類の書き込みを断る方針のとき")
    struct Rejecting {
        let record: SyncedWeightRecord
        let updateWriteId: UUID
        let createWriteId: UUID
        let newRecord: NewWeightRecord
        let client: NuToriAPIClient

        init() throws {
            record = .fixture(weightKilograms: 70.0, version: 1)
            updateWriteId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
            createWriteId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a2"))
            newRecord = NewWeightRecord(
                id: try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")),
                weightKilograms: 71.0, measuredAt: record.measuredAt, timeZone: record.timeZone,
                imported: nil)
            client = FakeSyncServerTests.client(
                .init(
                    records: [.weightRecord(record)], startedOn: FakeSyncServerTests.startedOn,
                    writePolicies: [FakeSyncServerTests.weightRecord: .reject]))
        }

        @Test("断ったと返し、記録があればその今の値を、無ければ無いことを添えること")
        func rejectsWithCurrent() async throws {
            let result = try await client.pushSyncWrites(
                [
                    .updateWeightRecord(writeId: updateWriteId, correction: .fixture()),
                    .createWeightRecord(writeId: createWriteId, record: newRecord),
                ],
                isFinalBatch: true, clientState: .fixture())

            #expect(
                result
                    == .pushed([
                        SyncWriteResult(
                            writeId: updateWriteId, outcome: .rejected(.outOfRange),
                            current: .value(.weightRecord(record))),
                        SyncWriteResult(
                            writeId: createWriteId, outcome: .rejected(.outOfRange),
                            current: .absent),
                    ]))
        }

        @Test("断った書き込みを記録に当てないこと")
        func keepsRecords() async throws {
            _ = try await client.pushSyncWrites(
                [.updateWeightRecord(writeId: updateWriteId, correction: .fixture())],
                isFinalBatch: true, clientState: .fixture())
            let result = try await client.pullSyncChanges(afterSequence: 1, clientState: .fixture())

            #expect(
                result
                    == .pulled(
                        SyncChangesPage(
                            changes: [], hasMore: false, nextAfterSequence: 1,
                            startedOn: FakeSyncServerTests.startedOn)))
        }
    }

    @Suite("記録の種類の書き込みがつながらない方針のとき")
    struct Unreachable {
        let client: NuToriAPIClient

        init() {
            client = FakeSyncServerTests.client(
                .init(
                    records: [], startedOn: FakeSyncServerTests.startedOn,
                    writePolicies: [FakeSyncServerTests.weightRecord: .unreachable]))
        }

        @Test("その種類の記録への書き込みを送ると、電波が無いときのエラーを投げること")
        func throwsNotConnected() async throws {
            let error = await #expect(throws: ClientError.self) {
                try await client.pushSyncWrites(
                    [.createWeightRecord(writeId: UUID(), record: .fixture())],
                    isFinalBatch: true, clientState: .fixture())
            }
            // 生成したクライアントは、トランスポートが投げたエラーを ClientError に包む
            #expect((error?.underlyingError as? URLError)?.code == .notConnectedToInternet)
        }
    }

    @Suite("食事を作る書き込みを受け付けたとき")
    struct MealEstimation {
        let meal: SyncedMeal
        let dish: SyncedDish
        let client: NuToriAPIClient

        init() async throws {
            let meal = try SyncedMeal.fixture()
            let dish = try SyncedDish.fixture(mealId: meal.id)
            self.meal = meal
            self.dish = dish
            client = FakeSyncServerTests.client(
                .init(
                    records: [], startedOn: FakeSyncServerTests.startedOn,
                    estimatedDishes: { _ in [.dish(dish)] }))
            _ = try await client.pushSyncWrites(
                [.createMeal(writeId: UUID(), meal: meal)], isFinalBatch: true,
                clientState: .fixture())
        }

        @Test("最初の取得で推定中を、次の取得で推定できたことと料理を返すこと")
        func estimatesOnNextPull() async throws {
            let first = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())
            let second = try await client.pullSyncChanges(afterSequence: 2, clientState: .fixture())

            #expect(
                first
                    == .pulled(
                        SyncChangesPage(
                            changes: [
                                .meal(meal),
                                .mealEstimationStatus(.init(mealId: meal.id, status: .estimating)),
                            ], hasMore: false, nextAfterSequence: 2,
                            startedOn: FakeSyncServerTests.startedOn)))
            #expect(
                second
                    == .pulled(
                        SyncChangesPage(
                            changes: [
                                .mealEstimationStatus(.init(mealId: meal.id, status: .estimated)),
                                .dish(dish),
                            ], hasMore: false, nextAfterSequence: 4,
                            startedOn: FakeSyncServerTests.startedOn)))
        }
    }

    @Suite("推定中を返した食事を消したとき")
    struct MealDeletedWhileEstimating {
        let meal: SyncedMeal
        let client: NuToriAPIClient

        init() async throws {
            let meal = try SyncedMeal.fixture()
            let dish = try SyncedDish.fixture(mealId: meal.id)
            self.meal = meal
            client = FakeSyncServerTests.client(
                .init(
                    records: [], startedOn: FakeSyncServerTests.startedOn,
                    estimatedDishes: { _ in [.dish(dish)] }))
            _ = try await client.pushSyncWrites(
                [.createMeal(writeId: UUID(), meal: meal)], isFinalBatch: true,
                clientState: .fixture())
            _ = try await client.pullSyncChanges(afterSequence: 0, clientState: .fixture())
        }

        @Test("食事の削除の印だけを返し、推定を終えないこと")
        func returnsDeletionWithoutEstimating() async throws {
            _ = try await client.pushSyncWrites(
                [.deleteMeal(writeId: UUID(), mealId: meal.id)], isFinalBatch: true,
                clientState: .fixture())
            let result = try await client.pullSyncChanges(afterSequence: 2, clientState: .fixture())

            #expect(
                result
                    == .pulled(
                        SyncChangesPage(
                            changes: [.mealDeletion(mealId: meal.id)], hasMore: false,
                            nextAfterSequence: 3, startedOn: FakeSyncServerTests.startedOn)))
        }
    }

    @Suite("アカウントの削除を断る方針のとき")
    struct AccountDeletionRateLimited {
        let client: NuToriAPIClient

        init() {
            client = FakeSyncServerTests.client(
                .init(
                    records: [], startedOn: FakeSyncServerTests.startedOn,
                    accountDeletion: .rateLimited))
        }

        @Test("削除の要求に、混み合っていると返すこと")
        func returnsRateLimited() async throws {
            #expect(try await client.deleteAccount() == .rateLimited)
        }
    }

    @Suite("電波が無い場面のとき")
    struct Offline {
        let client: NuToriAPIClient

        init() {
            client = FakeSyncServerTests.client(
                .init(records: [], startedOn: FakeSyncServerTests.startedOn, connection: .offline))
        }

        @Test("どの要求にも、電波が無いときのエラーを投げること")
        func throwsNotConnected() async throws {
            let error = await #expect(throws: ClientError.self) {
                try await client.startSession(
                    idToken: "id-token", nonce: "nonce", authorizationCode: "code",
                    timeZone: .current)
            }
            // 生成したクライアントは、トランスポートが投げたエラーを ClientError に包む
            #expect((error?.underlyingError as? URLError)?.code == .notConnectedToInternet)
        }
    }
}
