import Foundation
import NuToriCore
import Testing

@Suite("目標の設定のヘルスケアの読み取り")
struct GoalSetupHealthReaderTests {
    @Suite("許可")
    struct Authorization {
        @Suite("まだ求めていない種類があるとき")
        struct NotYetRequested {
            let healthStore: HealthStoreMock
            let reader: GoalSetupHealthReader

            init() {
                healthStore = .ok(
                    goalSetup: HealthStoreMock.GoalSetup(requestStatus: .notYetRequested))
                reader = .fixture(healthStore: healthStore)
            }

            @Test("まだ求めていない種類があると返すこと")
            func reportsUnrequested() async throws {
                #expect(try await reader.hasUnrequestedAuthorization())
            }

            @Test("目標の設定で使う種類の許可を求めること")
            func requestsAuthorization() async throws {
                try await reader.requestAuthorization()

                #expect(healthStore.goalSetupAuthorizationRequests == 1)
            }
        }

        @Suite("どの種類も求め終えているとき")
        struct AlreadyRequested {
            let reader: GoalSetupHealthReader

            init() {
                reader = .fixture(
                    healthStore: .ok(
                        goalSetup: HealthStoreMock.GoalSetup(requestStatus: .alreadyRequested)))
            }

            @Test("まだ求めていない種類は無いと返すこと")
            func reportsNothingUnrequested() async throws {
                #expect(try await !reader.hasUnrequestedAuthorization())
            }
        }
    }

    @Suite("使い始める前の摂取エネルギー")
    struct IntakeEnergy {
        @Suite("今日から使い始めたとき")
        struct FirstUseToday {
            let healthStore: HealthStoreMock
            let reader: GoalSetupHealthReader

            init() {
                healthStore = .ok()
                reader = .fixture(healthStore: healthStore)
            }

            @Test("今日を除く直前の 28 日を、端末のタイムゾーンの日付で読むこと")
            func readsInitialWindow() async throws {
                _ = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2026, month: 1, day: 1))

                #expect(
                    healthStore.dietaryEnergyReadRequests == [
                        HealthStoreMock.DailyReadRequest(
                            days: CalendarDay(
                                year: 2025, month: 12, day: 4)...CalendarDay(
                                    year: 2025, month: 12, day: 31),
                            timeZone: GoalSetupHealthReader.fixtureTimeZone
                        )
                    ])
            }
        }

        @Suite("初期値の窓の途中で使い始めたとき")
        struct FirstUseInsideWindow {
            let healthStore: HealthStoreMock
            let reader: GoalSetupHealthReader

            init() {
                healthStore = .ok()
                reader = .fixture(healthStore: healthStore)
            }

            @Test("使い始めた日の前の日までだけを読むこと")
            func readsOnlyDaysBeforeFirstUse() async throws {
                _ = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2025, month: 12, day: 20))

                #expect(
                    healthStore.dietaryEnergyReadRequests.map(\.days) == [
                        CalendarDay(
                            year: 2025, month: 12, day: 4)...CalendarDay(
                                year: 2025, month: 12, day: 19)
                    ])
            }
        }

        @Suite("初期値の窓より前から使っているとき")
        struct FirstUseBeforeWindow {
            let healthStore: HealthStoreMock
            let reader: GoalSetupHealthReader

            init() {
                healthStore = .ok(
                    goalSetup: HealthStoreMock.GoalSetup(dietaryEnergy: [
                        HealthDailySourceEnergy(
                            day: CalendarDay(year: 2025, month: 12, day: 10),
                            sourceBundleId: "com.example.food",
                            kilocalories: 1800
                        )
                    ]))
                reader = .fixture(healthStore: healthStore)
            }

            @Test("ヘルスケアを読まず、どの日も返さないこと")
            func readsNothing() async throws {
                let energy = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2025, month: 12, day: 4))

                #expect(energy.isEmpty)
                #expect(healthStore.dietaryEnergyReadRequests.isEmpty)
            }
        }

        @Suite("出どころが2つある日があるとき")
        struct TwoSourcesOnOneDay {
            let reader: GoalSetupHealthReader

            init() {
                let day = CalendarDay(year: 2025, month: 12, day: 10)
                reader = .fixture(
                    healthStore: .ok(
                        goalSetup: HealthStoreMock.GoalSetup(dietaryEnergy: [
                            HealthDailySourceEnergy(
                                day: day, sourceBundleId: "com.example.food", kilocalories: 1800),
                            HealthDailySourceEnergy(
                                day: day, sourceBundleId: "com.example.other", kilocalories: 2100),
                        ])))
            }

            @Test("足し合わせず、一番多い出どころの値にすること")
            func takesLargestSource() async throws {
                let energy = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2026, month: 1, day: 1))

                #expect(energy == [CalendarDay(year: 2025, month: 12, day: 10): 2100])
            }
        }

        @Suite("nu-tori 自身が書いた分があるとき")
        struct OwnSource {
            let reader: GoalSetupHealthReader

            init() {
                let sharedDay = CalendarDay(year: 2025, month: 12, day: 10)
                reader = .fixture(
                    healthStore: .ok(
                        goalSetup: HealthStoreMock.GoalSetup(dietaryEnergy: [
                            HealthDailySourceEnergy(
                                day: sharedDay,
                                sourceBundleId: GoalSetupHealthReader.ownBundleId,
                                kilocalories: 2500
                            ),
                            HealthDailySourceEnergy(
                                day: sharedDay,
                                sourceBundleId: "com.example.food",
                                kilocalories: 1800
                            ),
                            HealthDailySourceEnergy(
                                day: CalendarDay(year: 2025, month: 12, day: 11),
                                sourceBundleId: GoalSetupHealthReader.ownBundleId,
                                kilocalories: 2000
                            ),
                        ])))
            }

            @Test("nu-tori の分を除き、nu-tori の分しか無い日は返さないこと")
            func excludesOwnSource() async throws {
                let energy = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2026, month: 1, day: 1))

                #expect(energy == [CalendarDay(year: 2025, month: 12, day: 10): 1800])
            }
        }

        @Suite("読み取りの期間の境界が、初期値の窓の日の途中にあるとき")
        struct BoundaryInsideWindow {
            let reader: GoalSetupHealthReader

            init() throws {
                reader = .fixture(
                    healthStore: .ok(
                        goalSetup: HealthStoreMock.GoalSetup(
                            dietaryEnergy: [9, 10, 11].map {
                                HealthDailySourceEnergy(
                                    day: CalendarDay(year: 2025, month: 12, day: $0),
                                    sourceBundleId: "com.example.food",
                                    kilocalories: 1800
                                )
                            },
                            dietaryEnergyBoundary: try Date(
                                "2025-12-10T12:00:00+09:00", strategy: .iso8601)
                        )))
            }

            @Test("境界より前の日と境界をまたぐ日は返さず、0 にもしないこと")
            func omitsDaysNotWhollyAuthorized() async throws {
                let energy = try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2026, month: 1, day: 1))

                #expect(energy == [CalendarDay(year: 2025, month: 12, day: 11): 1800])
            }
        }
    }

    @Suite("身体データ")
    struct BodyData {
        @Suite("ヘルスケアにそろっているとき")
        struct AllAvailable {
            let healthStore: HealthStoreMock
            let reader: GoalSetupHealthReader

            init() {
                healthStore = .ok(
                    goalSetup: HealthStoreMock.GoalSetup(
                        dailySteps: [CalendarDay(year: 2025, month: 12, day: 30): 8200],
                        heightCentimeters: 172,
                        dateOfBirth: CalendarDay(year: 1990, month: 6, day: 15),
                        sex: .male
                    ))
                reader = .fixture(healthStore: healthStore)
            }

            @Test("生年月日を今日の満年齢にし、身長と性別と日ごとの歩数を返すこと")
            func returnsBodyData() async throws {
                #expect(
                    try await reader.bodyData()
                        == HealthBodyData(
                            heightCentimeters: 172,
                            age: 35,
                            sex: .male,
                            dailySteps: [CalendarDay(year: 2025, month: 12, day: 30): 8200]
                        ))
            }

            @Test("歩数は、今日を除く直前の 28 日を読むこと")
            func readsInitialWindow() async throws {
                _ = try await reader.bodyData()

                #expect(
                    healthStore.stepCountReadRequests.map(\.days) == [
                        CalendarDay(
                            year: 2025, month: 12, day: 4)...CalendarDay(
                                year: 2025, month: 12, day: 31)
                    ])
            }
        }

        @Suite("ヘルスケアに何も無いとき")
        struct NothingAvailable {
            let reader: GoalSetupHealthReader

            init() {
                reader = .fixture(healthStore: .ok())
            }

            @Test("どの値も、読めなかったものとして返すこと")
            func returnsUnknowns() async throws {
                #expect(
                    try await reader.bodyData()
                        == HealthBodyData(
                            heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:]))
            }
        }

        @Suite("歩数の読み取りの期間の境界が、初期値の窓の日の途中にあるとき")
        struct StepBoundaryInsideWindow {
            let reader: GoalSetupHealthReader

            init() throws {
                reader = .fixture(
                    healthStore: .ok(
                        goalSetup: HealthStoreMock.GoalSetup(
                            dailySteps: [
                                CalendarDay(year: 2025, month: 12, day: 10): 3000,
                                CalendarDay(year: 2025, month: 12, day: 11): 8200,
                            ],
                            stepCountBoundary: try Date(
                                "2025-12-10T12:00:00+09:00", strategy: .iso8601)
                        )))
            }

            @Test("境界をまたぐ日の歩数は返さないこと")
            func omitsDaysNotWhollyAuthorized() async throws {
                let steps = try await reader.bodyData().dailySteps

                #expect(steps == [CalendarDay(year: 2025, month: 12, day: 11): 8200])
            }
        }
    }

    @Suite("ヘルスケアを読めなかったとき")
    struct ReadFailure {
        let errorReporting: ErrorReportingSessionMock
        let reader: GoalSetupHealthReader

        init() {
            errorReporting = .ok()
            reader = .fixture(
                healthStore: .error(HealthReadError()), errorReporting: errorReporting)
        }

        @Test("失敗を投げ、ヘルスケアの読み取りの失敗として報告すること")
        func reportsHealthRead() async throws {
            await #expect(throws: HealthReadError.self) {
                try await reader.intakeEnergyBeforeFirstUse(
                    firstUseDay: CalendarDay(year: 2026, month: 1, day: 1))
            }
            #expect(errorReporting.reported == [.healthRead])
        }
    }
}

private struct HealthReadError: Error {}
