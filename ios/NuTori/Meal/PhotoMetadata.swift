import Foundation
import ImageIO
import NuToriCore

/// 写真の付帯情報から、撮影時刻と時差を読む。送る縮小版は EXIF を写さないので、縮小版を作る前に読む
nonisolated enum PhotoMetadata {
    /// 選んだ写真の元のバイトから読む。読めなければ撮影時刻が無いものにする
    static func exif(ofImageData data: Data) -> PhotoExif {
        // ImageIO は付帯情報を CFDictionary で返すので、確かめて Swift の辞書にする
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return PhotoExif.none
        }
        return exif(fromProperties: properties)
    }

    /// 付帯情報の辞書から読む。標準のカメラが返す付帯情報（`UIImagePickerController.InfoKey.mediaMetadata`）も同じ形
    static func exif(fromProperties properties: [String: Any]) -> PhotoExif {
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        return PhotoExif(
            dateTimeOriginal: exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String,
            offsetTimeOriginal: exif?[kCGImagePropertyExifOffsetTimeOriginal as String] as? String
        )
    }
}
