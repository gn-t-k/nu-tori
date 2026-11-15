import NuToriCore
import Testing

@Suite("対処した失敗の名前")
struct HandledFailureReportNameTests {
    /// Sentry の課題の題と過去の報告との突き合わせに使っている名前。変えると別の課題に割れる
    static let expectedNames: [(HandledFailure, String)] = [
        (.sync, "sync"),
        (.healthRead, "health_read"),
        (.healthWrite, "health_write"),
        (.healthNutritionWrite, "health_nutrition_write"),
        (.cacheSave, "cache_save"),
        (.storeRecovery, "store_recovery"),
        (.photoUpload, "photo_upload"),
        (.reminderSchedule, "reminder_schedule"),
        (.cacheRead, "cache_read"),
        (.notificationPermissionRequest, "notification_permission_request"),
        (.goalSetupRequest, "goal_setup_request"),
        (.appStoreSync, "app_store_sync"),
    ]

    @Test("どの種類も、これまで送ってきた名前のままであること")
    func keepsReportedNames() {
        for failure in HandledFailure.allCases {
            let expected = Self.expectedNames.first { $0.0 == failure }?.1
            #expect(failure.reportName == expected, "\(failure)")
        }
    }

    @Test("種類ごとに名前が違うこと")
    func namesAreDistinct() {
        let names = HandledFailure.allCases.map(\.reportName)
        #expect(Set(names).count == names.count)
    }
}
