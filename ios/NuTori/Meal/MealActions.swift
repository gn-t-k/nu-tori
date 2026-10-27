import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// タイムラインから、食事を撮る・選ぶ画面を開き、食事のカードと食事の画面の写真を読む操作。
/// 撮った・選んだ写真の記録と、食事と料理を直す・消す編集は `UserEdit` で渡す
struct MealActions {
    /// 「撮る」を押したとき。まだ求めていなければ、ここでカメラの許可を求める
    let prepareCamera: () async -> CameraReadiness
    /// 「写真」を押したときの選び方
    let photoSelection: MealPhotoSelection
    /// カードに描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ mealId: UUID, _ photoId: UUID) async -> UIImage?
}
