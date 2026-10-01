import Foundation
import ImageIO
import UIKit

/// カードに描く大きさに縮めて、食事の写真を読む。元の大きさの写真は 12MP のこともあるので、そのままは描かない
nonisolated enum MealPhotoImage {
    /// 読めなければ nil。縮めるのは重いので、メインの外で行う
    @concurrent static func thumbnail(at url: URL) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        // 向きは画素に当てるので、向きの付帯情報が無くても正しく見える
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    /// カードは画面の幅の 72%。3倍の画面でも粗く見えない大きさ
    private static let maxPixelSize = 900
}
