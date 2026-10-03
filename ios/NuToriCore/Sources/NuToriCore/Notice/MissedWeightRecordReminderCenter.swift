public import Foundation

/// 記録忘れの通知の置き場（`UNUserNotificationCenter` を呼ぶ薄い層）。この機能で置いた通知だけを扱う
public protocol MissedWeightRecordReminderCenter: Sendable {
    func permission() async -> NotificationPermission

    /// iPhone の画面で、通知の表示と音の許可を求める。許可したかを返す
    func requestPermission() async throws -> Bool

    /// 予約してある記録忘れの通知の ID
    func scheduledIds() async -> [UUID]

    /// 通知センターに残っている記録忘れの通知の ID
    func deliveredIds() async -> [UUID]

    /// 今の土地の時計の、その日付のその時刻に予約する。ID は `reminder.id`
    func schedule(_ reminder: MissedWeightRecordReminder) async throws

    func removeScheduled(ids: [UUID]) async

    func removeDelivered(ids: [UUID]) async
}

/// このアプリの通知の許可。アカウントの画面の「記録忘れ（体重）」の行にも出す
public enum NotificationPermission: Sendable, Equatable {
    case permitted
    /// 「許可しない」を選んだ
    case notPermitted
    case notYetRequested
}
