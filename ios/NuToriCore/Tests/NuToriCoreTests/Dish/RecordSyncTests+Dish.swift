import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension RecordSyncTests {
    @Suite("料理の名前を直したとき")
    struct RenamedDish {
        let device: RecordSyncDevice
        let dish: Dish

        init() async throws {
            let clock = SteppingClock()
            let mealId = UUID()
            let dishId = UUID()
            device = try RecordSyncDevice(
                clock: clock,
                server: .passing(
                    .init(
                        records: [
                            .meal(
                                SyncedMeal(
                                    id: mealId,
                                    eatenAt: Date(timeIntervalSince1970: 1_790_046_600),
                                    eatenUtcOffsetSeconds: 32_400,
                                    sentAt: Date(timeIntervalSince1970: 1_790_046_660),
                                    sentTimeZone: try #require(
                                        TimeZone(identifier: "Asia/Tokyo")),
                                    entryMethod: .captured, photoIds: [UUID()])),
                            .dish(
                                SyncedDish(
                                    id: dishId, mealId: mealId, name: "親子丼",
                                    quantity: .init(value: 1, unit: "杯", source: .estimated),
                                    positionInMeal: 0, version: 1)),
                        ],
                        startedOn: RecordSyncDevice.startedOn,
                        estimateDish: { _, _ in
                            .init(
                                quantity: .init(value: 1, unit: "杯", source: .estimated),
                                ingredients: [])
                        }),
                    clock: clock),
                goals: [try .maintaining()])
            _ = try await device.recordSync.sync()
            dish = try #require(device.store.cache.dishes[dishId])
        }

        @Test("送ってすぐ取りに行き、推定し直しを終えるまで3秒おきに取りに行くこと", .timeLimit(.minutes(1)))
        func followsReestimation() async throws {
            _ = try await device.recordSync.perform(.renameDish(dish, to: "カツ丼"), in: .gmt)
            await device.reflection.finishedSyncs.reaches(2)
            let statusAfterSending = device.store.cache.dishEstimationStatuses[dish.id]
            await device.advance(by: .seconds(3), untilFinishedSyncs: 3)

            #expect(statusAfterSending == .estimating)
            #expect(device.store.cache.dishEstimationStatuses[dish.id] == .estimated)
            #expect(device.server.pullTimes == [.zero, .zero, .seconds(3)])
        }
    }
}
