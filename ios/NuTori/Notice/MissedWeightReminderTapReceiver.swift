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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        guard
            request.content.categoryIdentifier
                == UserNotificationReminderCenter.categoryIdentifier,
            let noticeId = UUID(uuidString: request.identifier)
        else {
            return
        }
        await receive(noticeId)
    }

    private let onTap: (UUID) -> Void

    private func receive(_ noticeId: UUID) {
        onTap(noticeId)
    }
}
