import AVFoundation
import UIKit

/// 「撮る」を押したとき、標準のカメラを開けるか
enum CameraReadiness {
    case ready
    /// 「許可しない」を選んだ、または機能制限で使えない
    case notPermitted
    /// シミュレーターのように、カメラが無い
    case noCamera

    /// まだ許可を求めていなければ、ここで iOS の許可の画面を出し、その答えで決める
    static func prepare() async -> CameraReadiness {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return .noCamera
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .ready
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .ready : .notPermitted
        case .denied, .restricted:
            return .notPermitted
        @unknown default:
            return .notPermitted
        }
    }
}
