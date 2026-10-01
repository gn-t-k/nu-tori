import Foundation
import NuToriCore
import Testing

@Suite("端末の利用状況の出来事")
struct ClientUsageEventTests {
    @Suite("キーボードで体重を記録したとき")
    struct WeightRecordedFromKeyboard {
        let event: ClientUsageEvent

        init() {
            event = .weightRecorded(
                method: .keyboard,
                stepperPressCount: 2,
                duration: .seconds(9),
                showedTypoHint: true
            )
        }

        @Test("値ではなく手数だけを載せること")
        func omitsTheValue() {
            #expect(event.name == "weight_recorded")
            #expect(
                event.fields == [
                    "method": .token("keyboard"),
                    "stepper_press_count": .count(2),
                    "duration_seconds": .wholeSeconds(9),
                    "showed_typo_hint": .flag(true),
                ])
        }
    }

    @Suite("上のまとまりで直したとき")
    struct CorrectedFromDaySummary {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.daySummary)
        }

        @Test("場所を day_summary にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("day_summary")])
        }
    }

    @Suite("ほかの記録で直したとき")
    struct CorrectedFromOtherRecords {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.otherRecords)
        }

        @Test("場所を other_records にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("other_records")])
        }
    }

    @Suite("最近の記録で直したとき")
    struct CorrectedFromRecentRecords {
        let event: ClientUsageEvent

        init() {
            event = .weightCorrected(.recentRecords)
        }

        @Test("場所を recent_records にすること")
        func namesThePlace() {
            #expect(event.fields == ["place": .token("recent_records")])
        }
    }

    @Suite("選んだ写真で食事を記録したとき")
    struct MealRecordedFromPickedPhotos {
        let event: ClientUsageEvent

        init() {
            event = .mealRecorded(entry: .picked, photoCount: 7, mealCount: 3)
        }

        @Test("入口と写真の枚数と、まとめてできた食事の数を載せること")
        func carriesCounts() {
            #expect(event.name == "meal_recorded")
            #expect(
                event.fields == [
                    "entry": .token("picked"),
                    "photo_count": .count(7),
                    "meal_count": .count(3),
                ])
        }
    }

    @Suite("撮って食事を記録したとき")
    struct MealRecordedFromCamera {
        let event: ClientUsageEvent

        init() {
            event = .mealRecorded(entry: .captured, photoCount: 1, mealCount: 1)
        }

        @Test("入口を captured にすること")
        func namesTheEntry() {
            #expect(event.fields["entry"] == .token("captured"))
        }
    }

    @Suite("カメラを開いてやめたとき")
    struct CameraCancelled {
        @Test("中身を持たない出来事にすること")
        func hasNoFields() {
            let event = ClientUsageEvent.cameraCancelled

            #expect(event.name == "camera_cancelled")
            #expect(event.fields.isEmpty)
            #expect(event.screenToken == nil)
        }
    }

    @Suite("カメラの許可の知らせを出したとき")
    struct CameraPermissionNoticeShown {
        @Test("中身を持たない出来事にすること")
        func hasNoFields() {
            let event = ClientUsageEvent.cameraPermissionNoticeShown

            #expect(event.name == "camera_permission_notice_shown")
            #expect(event.fields.isEmpty)
            #expect(event.screenToken == nil)
        }
    }

    @Suite("推定できた食事を、送ってから 30 分 30 秒後に消したとき")
    struct EstimatedMealDeleted {
        let event: ClientUsageEvent

        init() throws {
            let card = try MealCard.fixture(
                eatenAt: "2026-09-24T12:10:00+09:00", sentAt: "2026-09-24T12:11:00+09:00",
                status: .estimated, nutrients: [.energyKcal: 510])
            event = .mealDeleted(
                card, at: try Date("2026-09-24T12:41:30+09:00", strategy: .iso8601))
        }

        @Test("推定の状態と、送ってから消すまでの秒を載せること")
        func carriesStateAndAge() {
            #expect(event.name == "meal_deleted")
            #expect(
                event.fields == [
                    "estimation_state": .token("estimated"),
                    "seconds_since_recorded": .wholeSeconds(1830),
                ])
            #expect(event.screenToken == nil)
        }
    }

    @Suite("推定の状態ごとに食事を消したとき")
    struct MealDeletedInEachState {
        @Test("カードの状態を名前にすること")
        func namesTheState() throws {
            #expect(
                try Self.stateToken(status: nil, recordedOnThisDevice: true) == .token("not_sent"))
            #expect(
                try Self.stateToken(status: .awaitingPhotos, recordedOnThisDevice: false)
                    == .token("awaiting_photos"))
            #expect(try Self.stateToken(status: .estimating) == .token("estimating"))
            #expect(try Self.stateToken(status: .noDishes) == .token("no_dishes"))
            #expect(
                try Self.stateToken(status: .deferredToNextDay) == .token("deferred_to_next_day"))
            #expect(try Self.stateToken(status: .failed) == .token("failed"))
        }

        private static func stateToken(
            status: MealEstimationStatus?, recordedOnThisDevice: Bool = true
        ) throws -> ClientUsageEvent.Field? {
            let card = try MealCard.fixture(
                status: status, recordedOnThisDevice: recordedOnThisDevice)
            return ClientUsageEvent.mealDeleted(card, at: card.meal.sentAt)
                .fields["estimation_state"]
        }
    }

    @Suite("端末の時計が送った時刻より前のとき")
    struct MealDeletedBeforeSentAt {
        @Test("消すまでの秒を 0 にすること")
        func clampsToZero() throws {
            let card = try MealCard.fixture(status: .estimating)

            let event = ClientUsageEvent.mealDeleted(
                card, at: card.meal.sentAt.addingTimeInterval(-90))

            #expect(event.fields["seconds_since_recorded"] == .wholeSeconds(0))
        }
    }

    @Suite("食事の画面と栄養の出典を開いたとき")
    struct MealScreens {
        @Test("画面の名前を送ること")
        func namesTheScreen() {
            #expect(ClientUsageEvent.screen(.meal).screenToken == "meal")
            #expect(ClientUsageEvent.screen(.nutrientCitation).screenToken == "nutrient_citation")
        }
    }
}
