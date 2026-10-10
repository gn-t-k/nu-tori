import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

@Suite("送り待ちを送った本文の読み口")
struct SentSyncWritesTests {
    @Suite("どの種類の書き込みも送ったとき")
    struct AllKinds {
        let writes: [SyncWrite]
        let transport: ClientTransportMock
        let client: NuToriAPIClient

        init() throws {
            let recordId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000b1"))
            let noticeId = try #require(UUID(uuidString: "00000000-0000-5000-8000-0000000000a1"))
            let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
            writes = [
                .createWeightRecord(
                    writeId: UUID(),
                    record: .fixture(
                        imported: .init(
                            sourceAppName: "Withings", sourceBundleId: "com.withings.wiScaleNG",
                            healthKitSampleId: UUID(),
                            bodyFat: .init(percentage: 18.5, healthKitSampleId: UUID())))),
                .updateWeightRecord(writeId: UUID(), correction: .fixture()),
                .sourceDeletedWeightRecord(writeId: UUID(), weightRecordId: recordId),
                .updateAccountSettings(
                    writeId: UUID(),
                    settings: SyncedAccountSettings(id: UUID(), sendsUsageData: true)),
                .createMeal(writeId: UUID(), meal: try .fixture()),
                .updateMeal(
                    writeId: UUID(), mealId: UUID(),
                    eatenAt: Date(timeIntervalSince1970: 1_767_229_200)),
                .deleteMeal(writeId: UUID(), mealId: UUID()),
                .createDish(
                    writeId: UUID(),
                    dish: NewDish(id: UUID(), mealId: UUID(), name: "味噌汁", positionInMeal: 2)),
                .deleteDish(writeId: UUID(), dishId: UUID()),
                .updateDish(
                    writeId: UUID(),
                    correction: DishCorrection(
                        id: UUID(), name: "親子丼",
                        quantity: .init(
                            value: 1.5,
                            proportionedIngredients: [
                                .init(ingredientId: UUID(), quantity: 120)
                            ]))),
                .updateDish(
                    writeId: UUID(),
                    correction: DishCorrection(id: UUID(), name: "味噌汁", quantity: nil)),
                .updateIngredient(writeId: UUID(), ingredientId: UUID(), quantity: 150),
                .createNotice(
                    writeId: UUID(),
                    notice: NewNotice(
                        id: noticeId, noticeType: .missedWeightRecord,
                        issuedAt: Date(timeIntervalSince1970: 1_767_225_600), timeZone: tokyo,
                        targetOn: "2026-01-01")),
                .respondNotice(
                    writeId: UUID(), noticeId: noticeId,
                    response: SyncedNotice.Response(
                        respondedAt: Date(timeIntervalSince1970: 1_767_229_200), timeZone: tokyo)),
                .createSentText(
                    writeId: UUID(),
                    sentText: SyncedSentText(
                        id: recordId, body: "昼に親子丼",
                        sentAt: Date(timeIntervalSince1970: 1_767_229_200), timeZone: tokyo)),
                .resendSentTextAsConversation(writeId: UUID(), sentTextId: recordId),
            ]
            transport = .sync()
            client = NuToriAPIClient(
                serverURL: URL(string: "https://api.example")!,
                transport: transport,
                appBuildGate: .sample,
                sessionToken: { "session-1" }
            )
        }

        @Test("送った書き込みと端末の状態と送り切った印を、送る前の型に戻して読むこと")
        func readsBackAsSent() async throws {
            _ = try await client.pushSyncWrites(
                writes, isFinalBatch: false, clientState: .fixture())

            let sent = try #require(try transport.pushBodies.first)
            #expect(sent.writes == writes)
            #expect(sent.clientState == .fixture())
            #expect(!sent.isFinalBatch)
        }
    }
}
