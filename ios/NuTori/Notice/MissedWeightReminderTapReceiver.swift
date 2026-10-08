import Foundation
import UserNotifications

/// 記録忘れの通知を押したことを受け取り、押した通知の ID（その日の体重の知らせの ID）を渡す。
/// 開いているあいだに届いた通知は出さない。同じ時刻にタイムラインに知らせが出るため
final class MissedWeightReminderTapReceiver: NSObject, UNUserNotificationCenterDelegate {
    init(onTap: @escaping (UUID) -> Void) {
        self.onTap = onTap
        super.init()
    }

    /// 通知を押してアプリが起動されたときにも受け取れるよう、起動の中で呼ぶ
    func startReceiving() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// UIKit は完了の閉包の中で画面の控えを撮り直し、メインのスレッドの外で呼ぶと落とす。
    /// async 版は終わったときにほかのスレッドで完了を呼ぶので、閉包の版にしてメインで呼ぶ
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let noticeId: UUID? =
            if request.content.categoryIdentifier
                == UserNotificationReminderCenter.categoryIdentifier
            {
                UUID(uuidString: request.identifier)
            } else {
                nil
            }
        // SDK は閉包を Sendable と書いていないが、メインで呼ぶことを求めているので、メインへ渡してよい
        nonisolated(unsafe) let completionHandler = completionHandler
        Task { @MainActor in
            if let noticeId {
                receive(noticeId)
            }
            completionHandler()
        }
    }

    private let onTap: (UUID) -> Void

    private func receive(_ noticeId: UUID) {
        onTap(noticeId)
    }
}
