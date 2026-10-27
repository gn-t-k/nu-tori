import Foundation
import NuToriCore
import Testing

@Suite("タイムラインの画面の移り方")
struct TimelineNavigationTests {
    @Suite("帯の日を押したとき")
    struct DayRingTapped {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot
        let day: CalendarDay

        init() throws {
            day = CalendarDay(year: 2026, month: 10, day: 29)
            snapshot = try .fixture()
            navigation = TimelineNavigation()
        }

        @Test("その日の日のまとめを出すこと")
        mutating func showsDaySummary() {
            _ = navigation.receive(.dayRingTapped(day), on: snapshot)
            #expect(navigation.presentation == .daySummary(day))
        }
    }

    @Suite("日のまとめを出しているとき")
    struct FromDaySummary {
        @Suite("目標があるとき")
        struct WithGoal {
            var navigation: TimelineNavigation
            let snapshot: TimelineSnapshot
            let day: CalendarDay

            init() throws {
                day = CalendarDay(year: 2026, month: 10, day: 29)
                snapshot = try .fixture(goals: [try Goal.losing()])
                navigation = TimelineNavigation()
                _ = navigation.receive(.dayRingTapped(day), on: snapshot)
            }

            @Test("目標の画面を求めると、日のまとめを閉じて目標の画面へ潜ること")
            mutating func opensGoalScreen() {
                _ = navigation.receive(.goalScreenRequested(.daySummary), on: snapshot)
                #expect(navigation.presentation == nil)
                #expect(navigation.path == [.goalScreen(.daySummary)])
            }

            @Test("週の振り返りを求めると、日のまとめを閉じてその週の月曜の振り返りへ潜ること")
            mutating func opensWeeklyReview() {
                _ = navigation.receive(
                    .weeklyReviewRequested(weekOf: day, .daySummary),
                    on: snapshot)
                #expect(navigation.presentation == nil)
                #expect(
                    navigation.path == [
                        .weeklyReview(
                            monday: CalendarDay(year: 2026, month: 10, day: 26), entry: .daySummary)
                    ])
            }

            @Test("体重の画面を求めると、日のまとめを閉じてその日の体重の画面へ潜ること")
            mutating func opensWeightScreen() {
                _ = navigation.receive(
                    .weightScreenRequested(day), on: snapshot)
                #expect(navigation.presentation == nil)
                #expect(navigation.path == [.weightScreen(day)])
            }
        }

        @Suite("目標がないとき")
        struct NoGoal {
            var navigation: TimelineNavigation
            let snapshot: TimelineSnapshot
            let day: CalendarDay

            init() throws {
                day = CalendarDay(year: 2026, month: 10, day: 29)
                snapshot = try .fixture(notices: [
                    try UnansweredNoticeLineTests.goalSetup(issuedAt: "2026-10-01T09:00:00+09:00")
                ])
                navigation = TimelineNavigation()
                _ = navigation.receive(.dayRingTapped(day), on: snapshot)
            }

            @Test("目標の画面を求めても、日のまとめを出したまま潜らないこと")
            mutating func staysOnDaySummary() {
                _ = navigation.receive(.goalScreenRequested(.daySummary), on: snapshot)
                #expect(navigation.presentation == .daySummary(day))
                #expect(navigation.path.isEmpty)
            }

            @Test("目標を立てると、日のまとめを閉じ、目標の設定をタイムラインで広げること")
            mutating func opensGoalSetup() {
                let effects = navigation.receive(.goalSetupRequested(.daySummary), on: snapshot)
                #expect(navigation.presentation == nil)
                #expect(effects == [.openGoalSetup(.daySummary)])
            }
        }
    }

    @Suite("体重の画面から目標の画面へ潜っているとき")
    struct Deep {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot
        let day: CalendarDay

        init() throws {
            day = CalendarDay(year: 2026, month: 10, day: 29)
            snapshot = try .fixture(goals: [try Goal.losing()])
            navigation = TimelineNavigation()
            _ = navigation.receive(
                .pathChanged([.weightScreen(day)]), on: snapshot)
            _ = navigation.receive(.goalScreenRequested(.weightScreen), on: snapshot)
        }

        @Test("体重の画面の上に目標の画面を積むこと")
        func stacksGoalScreen() {
            #expect(
                navigation.path == [
                    .weightScreen(day), .goalScreen(.weightScreen),
                ])
        }

        @Test("目標を立てると、タイムラインまで戻ること")
        mutating func returnsToTimelineForGoalSetup() {
            _ = navigation.receive(.goalSetupRequested(.chooseNextGoal), on: snapshot)
            #expect(navigation.path.isEmpty)
        }
    }

    @Suite("入力欄の体重を押したとき")
    struct WeightEntry {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot
        let effects: [TimelineNavigation.Effect]

        init() throws {
            snapshot = try .fixture()
            navigation = TimelineNavigation()
            effects = navigation.receive(.weightEntryTapped, on: snapshot)
        }

        @Test("シートを出す前に、用意を頼むこと")
        func preparesFirst() {
            #expect(effects == [.prepareWeightEntry])
            #expect(navigation.presentation == .weightEntry(.preparing))
        }

        @Test("用意しているあいだにもう一度押しても、用意を頼み直さないこと")
        mutating func ignoresSecondTap() {
            #expect(navigation.receive(.weightEntryTapped, on: snapshot).isEmpty)
        }

        @Test("用意し終えたら、シートを出すこと")
        mutating func showsSheet() {
            _ = navigation.receive(.weightEntryPrepared, on: snapshot)
            #expect(navigation.presentation == .weightEntry(.showing))
        }

        @Test("用意しているあいだにアカウントを開いたら、用意し終えても体重のシートを出さないこと")
        mutating func keepsAccountOpen() {
            _ = navigation.receive(.accountTapped, on: snapshot)
            _ = navigation.receive(.weightEntryPrepared, on: snapshot)
            #expect(navigation.presentation == .account)
        }
    }

    @Suite("体重のシートを出しているとき")
    struct WeightEntryShowing {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot

        init() throws {
            snapshot = try .fixture()
            navigation = TimelineNavigation()
            _ = navigation.receive(.weightEntryTapped, on: snapshot)
            _ = navigation.receive(.weightEntryPrepared, on: snapshot)
        }

        @Test("記録すると、閉じてタイムラインを見たことを送り、シートが消えてから通知の許可を求めること")
        mutating func recordsThenAsksPermission() {
            let recorded = navigation.receive(.weightRecordedInEntry, on: snapshot)
            let disappeared = navigation.receive(.weightEntryDisappeared, on: snapshot)
            #expect(navigation.presentation == nil)
            #expect(recorded == [.capture(.screen(.timeline))])
            #expect(disappeared == [.requestNotificationPermission])
        }

        @Test("記録せずに下へ送って閉じると、タイムラインを見たことを送り、通知の許可は求めないこと")
        mutating func dismissesWithoutRecording() {
            let dismissed = navigation.receive(
                .dismissed(.weightEntry(.showing)), on: snapshot)
            let disappeared = navigation.receive(.weightEntryDisappeared, on: snapshot)
            #expect(navigation.presentation == nil)
            #expect(dismissed == [.capture(.screen(.timeline))])
            #expect(disappeared.isEmpty)
        }
    }

    @Suite("入力欄のカメラを押したとき")
    struct Camera {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot
        let effects: [TimelineNavigation.Effect]

        init() throws {
            snapshot = try .fixture()
            navigation = TimelineNavigation()
            effects = navigation.receive(.cameraTapped, on: snapshot)
        }

        @Test("カメラを開く前に、許可を確かめるよう頼むこと")
        func preparesFirst() {
            #expect(effects == [.prepareCamera])
            #expect(navigation.presentation == .camera(.preparing))
        }

        @Test("許可されていなければ、開かずに知らせを出し、出したことを送ること")
        mutating func showsNoticeWhenNotPermitted() {
            let notPermitted = navigation.receive(.cameraNotPermitted, on: snapshot)
            #expect(navigation.presentation == .cameraPermissionNotice)
            #expect(notPermitted == [.capture(.cameraPermissionNoticeShown)])
        }
    }

    @Suite("カメラを許可していない知らせを出しているとき")
    struct CameraPermissionNotice {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot
        let day: CalendarDay

        init() throws {
            day = CalendarDay(year: 2026, month: 10, day: 29)
            snapshot = try .fixture()
            navigation = TimelineNavigation()
            _ = navigation.receive(.cameraTapped, on: snapshot)
            _ = navigation.receive(.cameraNotPermitted, on: snapshot)
        }

        @Test("タイムラインを動かすと、知らせを消すこと")
        mutating func hidesOnScroll() {
            _ = navigation.receive(.timelineScrolled, on: snapshot)
            #expect(navigation.presentation == nil)
        }

        @Test("帯の日を押すと、知らせを消して日のまとめを出すこと")
        mutating func replacedByDaySummary() {
            _ = navigation.receive(.dayRingTapped(day), on: snapshot)
            #expect(navigation.presentation == .daySummary(day))
        }
    }

    @Suite("カメラを開いているとき")
    struct CameraShowing {
        var navigation: TimelineNavigation
        let snapshot: TimelineSnapshot

        init() throws {
            snapshot = try .fixture()
            navigation = TimelineNavigation()
            _ = navigation.receive(.cameraTapped, on: snapshot)
            _ = navigation.receive(.cameraReady, on: snapshot)
        }

        @Test("取り消すと、閉じて取り消したこととタイムラインを見たことを送ること")
        mutating func cancels() {
            let cancelled = navigation.receive(.cameraCancelled, on: snapshot)
            #expect(navigation.presentation == nil)
            #expect(cancelled == [.capture(.cameraCancelled), .capture(.screen(.timeline))])
        }
    }

    @Suite("課金画面を求めたとき")
    struct Paywall {
        @Suite("無料体験が終わっているとき")
        struct Expired {
            var navigation: TimelineNavigation
            let snapshot: TimelineSnapshot
            let request: PaywallRequest

            init() throws {
                snapshot = try .fixture(
                    subscriptionStatus: .regular(
                        freeTrial: .available(lastDay: CalendarDay(year: 2026, month: 11, day: 1)),
                        subscription: .none))
                request = try #require(snapshot.paywallRequest(from: .noticeCard))
                navigation = TimelineNavigation()
            }

            @Test("開いたところを添えた求めで、課金画面を出すこと")
            mutating func opens() {
                _ = navigation.receive(.paywallRequested(.noticeCard), on: snapshot)
                #expect(navigation.presentation == .paywall(request))
            }
        }

        @Suite("テストユーザーのとき")
        struct TestUser {
            var navigation: TimelineNavigation
            let snapshot: TimelineSnapshot

            init() throws {
                snapshot = try .fixture(subscriptionStatus: .testUser)
                navigation = TimelineNavigation()
            }

            @Test("課金画面を出さないこと")
            mutating func doesNotOpen() {
                _ = navigation.receive(.paywallRequested(.noticeCard), on: snapshot)
                #expect(navigation.presentation == nil)
            }
        }
    }
}
