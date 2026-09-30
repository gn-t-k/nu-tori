#if DEBUG
    import Foundation
    import NuToriCore

    /// UI テストが起動の値で渡す、ヘルスケアの許可と読み書き
    nonisolated final class UITestHealthStore: HealthStore, @unchecked Sendable {
        init(authorization: Authorization, latestKilograms: Double?, writeAuthorized: Bool) {
            self.authorization = authorization
            self.latestKilograms = latestKilograms
            self.writeAuthorized = writeAuthorized
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
            return HealthChanges(
                weights: [
                    HealthChanges.WeightSample(
                        sampleId: Self.sampleId,
                        kilograms: latestKilograms,
                        instant: .now,
                        sourceAppName: "体重計アプリ",
                        sourceBundleId: "com.example.scale",
                        timeZone: .current
                    )
                ],
                bodyFats: [],
                deletions: [],
                anchor: next
            )
        }

        func writeWeight(_ write: HealthWeightWrite) async throws {}

        enum Authorization {
            case notYetRequested
            case alreadyRequested
        }

        private static let sampleId = UUID(uuidString: "00000000-0000-4000-8000-0000000000c1")!
        private var authorization: Authorization
        private let latestKilograms: Double?
        private let writeAuthorized: Bool
    }
#endif
