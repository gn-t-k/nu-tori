import AVFoundation

/// このアプリのカメラの許可。アカウントの画面の「食事を撮る」の行に出す
enum CameraAccess {
    case permitted
    /// 「許可しない」を選んだ、または機能制限で使えない
    case notPermitted
    case notYetRequested

    /// 設定で許可を切り替えると、iOS がアプリを終わらせるので、開き直したときに読み直される
    static func current() -> CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .permitted
        case .denied, .restricted: .notPermitted
        case .notDetermined: .notYetRequested
        @unknown default: .notPermitted
        }
    }

    var label: String {
        switch self {
        case .permitted: "許可している"
        case .notPermitted: "許可していない"
        case .notYetRequested: "まだ求めていない"
        }
    }
}
