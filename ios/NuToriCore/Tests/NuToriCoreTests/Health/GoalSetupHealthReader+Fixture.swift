import Foundation
import NuToriCore

extension GoalSetupHealthReader {
    static let ownBundleId = "app.nu-tori.example"
    static let fixtureTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    /// 今は日本時間の 2026-01-01 09:00。初期値の窓は 2025-12-04 から 2025-12-31
    static func fixture(
        healthStore: HealthStoreMock,
        errorReporting: ErrorReportingSessionMock = .ok()
    ) -> GoalSetupHealthReader {
        GoalSetupHealthReader(
            healthStore: healthStore,
            ownBundleId: ownBundleId,
            timeZone: { fixtureTimeZone },
            now: { Date(timeIntervalSince1970: 1_767_225_600) },
            errorReporting: errorReporting
        )
    }
}
