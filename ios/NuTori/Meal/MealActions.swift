import Foundation
import NuToriCore
import PhotosUI
import SwiftUI
import UIKit

/// タイムラインから、食事を撮る・選んで記録し、食事のカードの写真を読む操作
struct MealActions {
    /// 「撮る」を押したとき。まだ求めていなければ、ここでカメラの許可を求める
    let prepareCamera: () async -> CameraReadiness
    /// `sentAt` は「写真を使用」を押した時刻
    let recordCapturedPhoto: (_ original: Data, _ exif: PhotoExif, _ sentAt: Date) async -> Void
    /// `pickedAt` は選び終えた時刻。送った時刻と、撮影時刻の無い写真の時刻にする
    let recordPickedPhotos: (_ items: [PhotosPickerItem], _ pickedAt: Date) async -> Void
    /// カードに描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?
}
