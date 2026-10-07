import Foundation
import NuToriCore
import PhotosUI
import SwiftUI
import UIKit

/// タイムラインから、食事を撮る・選んで記録し、食事のカードと食事の画面の写真を読み、時刻を直し、料理を直し、食事を消す操作
struct MealActions {
    /// 「撮る」を押したとき。まだ求めていなければ、ここでカメラの許可を求める
    let prepareCamera: () async -> CameraReadiness
    /// `sentAt` は「写真を使用」を押した時刻
    let recordCapturedPhoto: (_ original: Data, _ exif: PhotoExif, _ sentAt: Date) async -> Void
    /// `pickedAt` は選び終えた時刻。送った時刻と、撮影時刻の無い写真の時刻にする
    let recordPickedPhotos: (_ items: [PhotosPickerItem], _ pickedAt: Date) async -> Void
    /// 「写真」を押したときの選び方
    let photoSelection: MealPhotoSelection
    /// カードに描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?
    /// 食事の画面の時刻を直したとき。`eatenAt` は直した撮った時刻
    let correctMealTime: (_ card: MealCard, _ eatenAt: Date) async -> Void
    /// 食事の画面の「食事を削除」。`deletedAt` は消した時刻で、送ってから消すまでの時間を測る
    let deleteMeal: (_ card: MealCard, _ deletedAt: Date) async -> Void
    /// 食事の画面の「料理を足す」で名前を確定したとき。前後の空白を除いて空の名前は足さない
    let addDish: (_ card: MealCard, _ typedName: String) async -> Void
    /// 料理の画面と、食事の画面の料理の行の操作
    let dish: DishActions
}
