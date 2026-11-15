import NuToriCore
import Testing

@Suite("対処した失敗の名前")
struct HandledFailureReportNameTests {
    // swiftlint:disable:next no_parameterized_test - 全部の種類を回し、種類を足したときに名前を決め忘れると落とすため
    @Test("これまで送ってきた名前のままであること", arguments: HandledFailure.allCases)
    func keepsReportedName(of failure: HandledFailure) {
        #expect(failure.reportName == Self.reportedName(of: failure))
    }

    /// 期待する名前を書くときに、ほかの種類と同じ名前を書いても上のテストは通るので、別に確かめる
    @Test("種類ごとに名前が違うこと")
    func namesAreDistinct() {
        let names = HandledFailure.allCases.map(\.reportName)
        #expect(Set(names).count == names.count)
    }

    /// Sentry の課題の題と過去の報告との突き合わせに使ってきた名前。変えると別の課題に割れる
    private static func reportedName(of failure: HandledFailure) -> String {
        switch failure {
        case .sync: "sync"
        case .healthRead: "health_read"
        case .healthWrite: "health_write"
        case .healthNutritionWrite: "health_nutrition_write"
        case .cacheSave: "cache_save"
        case .storeRecovery: "store_recovery"
        case .photoUpload: "photo_upload"
        case .reminderSchedule: "reminder_schedule"
        case .cacheRead: "cache_read"
        case .notificationPermissionRequest: "notification_permission_request"
        case .goalSetupRequest: "goal_setup_request"
        case .appStoreSync: "app_store_sync"
        }
    }
}
