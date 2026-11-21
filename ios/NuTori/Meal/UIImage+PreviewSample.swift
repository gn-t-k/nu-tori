#if DEBUG
    import Foundation
    import UIKit

    extension UIImage {
        /// プレビューの見本の、食事の写真の代わりの無地の画像。写真ごとに色を変える
        static func sampleMealPhoto(for photoId: UUID) -> UIImage {
            let hue = CGFloat(photoId.uuid.0) / 255
            let size = CGSize(width: 400, height: 300)
            return UIGraphicsImageRenderer(size: size).image { context in
                UIColor(hue: hue, saturation: 0.35, brightness: 0.85, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
    }
#endif
