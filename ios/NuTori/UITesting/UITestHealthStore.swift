#if DEBUG
    import Foundation
    import NuToriCore

    /// UI テストが起動の値で渡す、ヘルスケアの許可と読み書き
    nonisolated final class UITestHealthStore: HealthStore, @unchecked Sendable {
        init(
            authorization: Authorization, latestKilograms: Double?, writeAuthorized: Bool,
            clock: DeviceClock
        ) {
            self.authorization = authorization
            self.latestKilograms = latestKilograms
            self.writeAuthorized = writeAuthorized
            self.clock = clock
        }

        func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
            switch authorization {
            case .notYetRequested: .notYetRequested
            case .alreadyRequested: .alreadyRequested
            }
        }

        func requestAuthorization() async throws {
            authorization = .alreadyRequested
        }

        func isWeightWriteAuthorized() async throws -> Bool {
            writeAuthorized
        }

        func earliestAuthorizedSampleDate() async throws -> Date? {
            nil
        }

        func readWeightChanges(after anchor: HealthAnchor?, notBefore: Date?) async throws
            -> HealthChanges
        {
            let next = HealthAnchor(data: Data([1]))
            guard anchor == nil, let latestKilograms else {
                return HealthChanges(weights: [], bodyFats: [], deletions: [], anchor: next)
            }
            let sampleId = UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")!
            return HealthChanges(
                weights: [
                    HealthChanges.WeightSample(
                        sampleId: sampleId,
                        kilograms: latestKilograms,
                        instant: clock.now(),
                        sourceAppName: "体重計アプリ",
                        sourceBundleId: "com.example.scale",
                        timeZone: clock.timeZone()
                    )
                ],
                bodyFats: [],
                deletions: [],
                anchor: next
            )
        }

        func writeWeight(_ write: HealthWeightWrite) async throws {}

        /// UI テストは栄養の許可の画面を出さない
        func nutritionAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus
        {
            .alreadyRequested
        }

        func requestNutritionAuthorization() async throws {}

        func writeAuthorizedNutrients() async throws -> Set<HealthNutrient> {
            writeAuthorized ? Set(HealthNutrient.allCases) : []
        }

        func writeNutrition(_ write: HealthNutritionWrite) async throws {}

        func deleteNutrition(syncId: UUID) async throws {}

        /// UI テストは目標の設定の許可の画面を出さず、身体データも摂取エネルギーも読めなかったものにする
        func goalSetupAuthorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus
        {
            .alreadyRequested
        }

        func requestGoalSetupAuthorization() async throws {}

        func earliestAuthorizedSampleDate(for quantity: HealthDailyQuantity) async throws -> Date? {
            nil
        }

        func readDailyDietaryEnergyBySource(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
            async throws -> [HealthDailySourceEnergy]
        {
            []
        }

        func readDailyStepCounts(days: ClosedRange<CalendarDay>, in timeZone: TimeZone)
            async throws -> [CalendarDay: Int]
        {
            [:]
        }

        func readLatestHeightCentimeters() async throws -> Double? { nil }

        func readDateOfBirth() async throws -> CalendarDay? { nil }

        func readBiologicalSex() async throws -> BiologicalSex? { nil }

        enum Authorization {
            case notYetRequested
            case alreadyRequested
        }

        private var authorization: Authorization
        private let latestKilograms: Double?
        private let writeAuthorized: Bool
        private let clock: DeviceClock
    }
#endif
