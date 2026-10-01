import Foundation
import NuToriCore
import SwiftUI
import UIKit

/// 食事のカードと食事の画面が、出す写真を読み、読み終えた写真を `images` に入れる。
/// 写真がサーバーに届くと推定の状態が変わるので、状態が変わったら、まだ読めていない写真を取りに行き直す
struct MealPhotosLoading: ViewModifier {
    let photoIds: [UUID]
    let state: MealCardState
    @Binding var images: [UUID: UIImage]
    /// 描く大きさに縮めた写真。この端末に無ければ取りに行く。取れなければ nil
    let loadPhoto: (_ photoId: UUID) async -> UIImage?

    func body(content: Content) -> some View {
        content.task(id: Request(photoIds: photoIds, state: state)) {
            for photoId in photoIds where images[photoId] == nil {
                if let image = await loadPhoto(photoId) {
                    images[photoId] = image
                }
            }
        }
    }

    private struct Request: Equatable {
        let photoIds: [UUID]
        let state: MealCardState
    }
}
