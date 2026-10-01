import Foundation
import NuToriCore
import Testing

@Suite("食事のカードの状態")
struct MealCardTests {
    @Suite("この端末で記録した食事")
    struct RecordedOnThisDevice {
        let meal: Meal

        init() throws {
            meal = try .fixture(eatenAt: "2026-09-24T03:10:00Z", sentAt: "2026-09-24T03:11:00Z")
        }

        @Test("推定の状態がまだ届いていなければ、まだ送れていないにすること")
        func noStatusIsNotSent() {
            #expect(
                MealCard(meal: meal, status: nil, recordedOnThisDevice: true).state == .notSent)
        }

        @Test("写真を待っているあいだも、まだ送れていないと同じにすること")
        func awaitingPhotosIsNotSent() {
            #expect(
                MealCard(meal: meal, status: .awaitingPhotos, recordedOnThisDevice: true).state
                    == .notSent)
        }

        @Test("推定中・推定できた・料理なし・翌日に推定・推定できなかったは、そのまま見せること")
        func laterStatusesAsIs() {
            let states = [
                MealEstimationStatus.estimating, .estimated, .noDishes, .deferredToNextDay, .failed,
            ].map { MealCard(meal: meal, status: $0, recordedOnThisDevice: true).state }

            #expect(states == [.estimating, .estimated, .noDishes, .deferredToNextDay, .failed])
        }
    }

    @Suite("ほかの端末で記録した食事")
    struct RecordedOnAnotherDevice {
        let meal: Meal

        init() throws {
            meal = try .fixture(eatenAt: "2026-09-24T03:10:00Z", sentAt: "2026-09-24T03:11:00Z")
        }

        @Test("写真を待っている食事は、写真を待っているにすること")
        func awaitingPhotosIsAwaitingPhotos() {
            #expect(
                MealCard(meal: meal, status: .awaitingPhotos, recordedOnThisDevice: false).state
                    == .awaitingPhotos)
        }

        @Test("推定の状態がまだ届いていなければ、写真を待っていると同じにすること")
        func noStatusIsAwaitingPhotos() {
            #expect(
                MealCard(meal: meal, status: nil, recordedOnThisDevice: false).state
                    == .awaitingPhotos)
        }

        @Test("推定中は、推定中にすること")
        func estimatingIsEstimating() {
            #expect(
                MealCard(meal: meal, status: .estimating, recordedOnThisDevice: false).state
                    == .estimating)
        }
    }
}
