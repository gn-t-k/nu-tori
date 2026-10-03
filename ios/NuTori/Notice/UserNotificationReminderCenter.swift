import Foundation
import NuToriCore
import UserNotifications

/// `UNUserNotificationCenter` に、記録忘れの通知を置き、外す。この機能で置いた通知は、分類の ID で見分ける
nonisolated struct UserNotificationReminderCenter: MissedWeightRecordReminderCenter {
    /// 記録忘れの通知に付ける分類の ID
    static let categoryIdentifier = "missed-weight-record"

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .permitted
        case .denied: .notPermitted
        case .notDetermined: .notYetRequested
        @unknown default: .notPermitted
        }
    }

    /// バッジは求めない
    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduledIds() async -> [UUID] {
        await center.pendingNotificationRequests()
            .filter { $0.content.categoryIdentifier == Self.categoryIdentifier }
            .compactMap { UUID(uuidString: $0.identifier) }
    }

    func deliveredIds() async -> [UUID] {
        await center.deliveredNotifications()
            .filter { $0.request.content.categoryIdentifier == Self.categoryIdentifier }
            .compactMap { UUID(uuidString: $0.request.identifier) }
    }

    func schedule(_ reminder: MissedWeightRecordReminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = "今日の体重がまだです"
        content.body = "いつもはこの時間までに記録しています。"
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        // タイムゾーンを持たせず、端末が今いる土地の時計の、その日付のその時刻に届ける
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                year: reminder.day.year,
                month: reminder.day.month,
                day: reminder.day.day,
                hour: reminder.clockTime.hour,
                minute: reminder.clockTime.minute
            ),
            repeats: false
        )
        try await center.add(
            UNNotificationRequest(
                identifier: reminder.id.uuidString, content: content, trigger: trigger))
    }

    func removeScheduled(ids: [UUID]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids.map(\.uuidString))
    }

    func removeDelivered(ids: [UUID]) async {
        center.removeDeliveredNotifications(withIdentifiers: ids.map(\.uuidString))
    }

    /// 持たずに都度取る。アプリで1つの置き場なので、どこから取っても同じもの
    private var center: UNUserNotificationCenter { .current() }
}
