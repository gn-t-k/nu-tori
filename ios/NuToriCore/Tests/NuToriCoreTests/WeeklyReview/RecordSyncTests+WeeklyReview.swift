import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension RecordSyncTests {
    @Suite("週の見直しが読める版に上げて最初に開き、前の版が読み飛ばした見直しがサーバーにあるとき")
    struct FirstOpenAfterWeeklyReviewUpdate {
        let device: RecordSyncDevice
        let goal: Goal
        let reviewId = UUID()

        init() throws {
            let clock = SteppingClock()
            goal = try Goal.maintaining()
            // 前の版は、通し番号 2 の見直しを知らない種類として読み飛ばしている
            device = try RecordSyncDevice(
                clock: clock,
                server: .passing(
                    .init(
                        records: [
                            .goal(try .maintaining(id: goal.id)),
                            .weeklyReview(
                                try WeeklyReviewSyncingTests.synced(
                                    id: reviewId,
                                    outcome: .deferred(reason: .noWeight, goalId: goal.id))),
                        ], startedOn: RecordSyncDevice.startedOn), clock: clock),
                goals: [goal],
                stateBeforeUpdate: (
                    2, RecordKindRegistry<RecordCacheMock>.ok().names.subtracting([.weeklyReview])
                ))
        }

        @Test("全部取り直して、見直しを受け取ること", .timeLimit(.minutes(1)))
        func pullsEverythingAgain() async throws {
            _ = try await device.recordSync.sync()

            #expect(Array(device.store.cache.weeklyReviews.keys) == [reviewId])
            #expect(device.store.state?.readableKinds.contains(.weeklyReview) == true)
        }
    }
}
