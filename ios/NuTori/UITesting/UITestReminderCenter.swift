#if DEBUG
    import Foundation
    import NuToriCore

    /// UI テストは通知を置かない。許可の画面は UI テストで安定して動かせないので、許可しなかったことにして求めない
    nonisolated struct UITestReminderCenter: MissedWeightRecordReminderCenter {
        func permission() async -> NotificationPermission {
            .notPermitted
        }

        func requestPermission() async throws -> Bool {
            false
        }

        func scheduledIds() async -> [UUID] {
            []
        }

        func deliveredIds() async -> [UUID] {
            []
        }

        func schedule(_ reminder: MissedWeightRecordReminder) async throws {}

        func removeScheduled(ids: [UUID]) async {}

        func removeDelivered(ids: [UUID]) async {}
    }
#endif
