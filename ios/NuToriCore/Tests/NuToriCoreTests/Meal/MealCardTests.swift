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

    @Suite("名前の場所に置く状態の1行")
    struct StatusLine {
        @Test("推定中は、推定していることを書くこと")
        func estimating() {
            #expect(MealCardState.estimating.statusLine == "推定しています…")
        }

        @Test("料理なしは、料理が見つからなかったことを書くこと")
        func noDishes() {
            #expect(MealCardState.noDishes.statusLine == "写真に料理が見つかりませんでした")
        }

        @Test("翌日に推定は、明日推定することを書くこと")
        func deferredToNextDay() {
            #expect(
                MealCardState.deferredToNextDay.statusLine == "今日はもう推定できないため、明日推定します")
        }

        @Test("推定できなかったは、推定できなかったことを書くこと")
        func failed() {
            #expect(MealCardState.failed.statusLine == "推定できませんでした")
        }

        @Test("まだ送れていない・写真を待っているは、何も置かないこと")
        func leavesEmpty() {
            #expect(MealCardState.notSent.statusLine == nil)
            #expect(MealCardState.awaitingPhotos.statusLine == nil)
        }

        @Test("推定できた食事は、状態の1行の代わりに料理の名前を置くので、1行を持たないこと")
        func estimatedHasNoLine() {
            #expect(MealCardState.estimated.statusLine == nil)
        }
    }

    @Suite("カードに出す時刻")
    struct EatenTime {
        @Test("撮った日がカードを置く日と同じなら、時刻だけにすること")
        func sameDayShowsClockOnly() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T19:40:00+09:00", sentAt: "2026-09-24T19:41:00+09:00")

            #expect(
                MealCard(meal: meal, status: nil, recordedOnThisDevice: true).eatenTime
                    == .clock(ClockTime(hour: 19, minute: 40)))
        }

        @Test("前の日に撮った写真を今日選んだら、撮った日を添えること")
        func earlierDayShowsDay() throws {
            let meal = try Meal.fixture(
                eatenAt: "2026-09-23T19:40:00+09:00", sentAt: "2026-09-24T08:00:00+09:00")

            #expect(
                MealCard(meal: meal, status: nil, recordedOnThisDevice: true).eatenTime
                    == .dayAndClock(
                        CalendarDay(year: 2026, month: 9, day: 23),
                        ClockTime(hour: 19, minute: 40)))
        }

        @Test("旅先で撮った写真は、食事の時差の時計で日と時刻を出すこと")
        func usesMealOffset() throws {
            // ロサンゼルスの 9月23日 18:00 に撮り、東京に戻った 9月24日 12:00 に選んだ
            let meal = try Meal.fixture(
                eatenAt: "2026-09-24T01:00:00Z", utcOffsetSeconds: -7 * 3600,
                sentAt: "2026-09-24T12:00:00+09:00")

            #expect(
                MealCard(meal: meal, status: nil, recordedOnThisDevice: true).eatenTime
                    == .dayAndClock(
                        CalendarDay(year: 2026, month: 9, day: 23),
                        ClockTime(hour: 18, minute: 0)))
        }
    }

    @Suite("写真の並べ方")
    struct Photos {
        let ids: [UUID]

        init() {
            ids = (0..<4).map { _ in UUID() }
        }

        @Test("1枚なら、その1枚を大きく出すこと")
        func singlePhoto() throws {
            #expect(try card(photoCount: 1).photos == .single(ids[0]))
        }

        @Test("2枚なら、2枚を並べて残りを数えないこと")
        func twoPhotos() throws {
            #expect(try card(photoCount: 2).photos == .pair(ids[0], ids[1], remaining: 0))
        }

        @Test("3枚以上なら、先の2枚を並べ、残りの枚数を数えること")
        func morePhotos() throws {
            #expect(try card(photoCount: 3).photos == .pair(ids[0], ids[1], remaining: 1))
            #expect(try card(photoCount: 4).photos == .pair(ids[0], ids[1], remaining: 2))
        }

        @Test("写真が無ければ、写真の場所を置かないこと")
        func noPhotos() throws {
            #expect(try card(photoCount: 0).photos == .none)
        }

        private func card(photoCount: Int) throws -> MealCard {
            MealCard(
                meal: try .fixture(
                    eatenAt: "2026-09-24T19:40:00+09:00", sentAt: "2026-09-24T19:41:00+09:00",
                    photoIds: Array(ids.prefix(photoCount))),
                status: nil,
                recordedOnThisDevice: true)
        }
    }
}
