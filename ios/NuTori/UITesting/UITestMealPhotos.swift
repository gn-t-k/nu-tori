#if DEBUG
    import Foundation
    import UIKit

    /// UI テストで選んだことにする写真。撮影時刻の付帯情報が無いので、選んだ時刻の食事になる
    enum UITestMealPhotos {
        /// 写真ごとに色を変えた、無地の JPEG。iPhone で縦に撮った写真と同じ縦長にし、
        /// カードの横長の枠からはみ出す写真でも、タイムラインのほかの行を押せることを確かめられるようにする
        static func jpegs(count: Int) -> [Data] {
            let size = CGSize(width: 600, height: 800)
            return (0..<count).map { index in
                UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) {
                    context in
                    UIColor(
                        hue: CGFloat(index) / CGFloat(max(count, 1)), saturation: 0.4,
                        brightness: 0.85, alpha: 1
                    )
                    .setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
            }
        }
    }
#endif
