public import Foundation
public import NuToriAPI

/// 写真の縮小版を裏で送るもの（アプリでは、バックグラウンドの URLSession）。
/// 結果は、送り始めた側を通さずに `MealPhotos.finishUpload` に届ける
public protocol MealPhotoUploader: Sendable {
    /// `file` を本文にして送り始める。送り終えるまで、ファイルを消さずに残す
    func startUpload(_ upload: MealPhotoUpload, file: URL, request: MealPhotoUploadRequest) async

    /// 送っている途中の写真。App スイッチャーで閉じると、送信ごと無くなる
    func uploadsInFlight() async -> Set<MealPhotoUpload>

    func cancelUploads(ofMeal mealId: UUID) async

    func cancelAllUploads() async
}
