import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 写真の控えにする縮小版（長辺 1024px、EXIF なしの JPEG。ADR-0008）を、元の写真から作る
nonisolated enum MealPhotoThumbnail {
    static func jpeg(from original: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(original as CFData, nil) else {
            throw UnreadableImageError()
        }
        // 向きは画素に当てるので、向きの付帯情報が無くても正しく見える
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
        ]
        guard
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0, thumbnailOptions as CFDictionary)
        else {
            throw UnreadableImageError()
        }
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            throw UnwritableImageError()
        }
        // 元の写真の付帯情報（EXIF・位置）を写さず、画素だけを書く
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw UnwritableImageError()
        }
        return output as Data
    }

    struct UnreadableImageError: Error {}

    struct UnwritableImageError: Error {}
}
