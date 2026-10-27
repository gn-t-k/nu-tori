public import Foundation

/// 撮った・選んだ元の写真と、その付帯情報（読むのはアプリのターゲット）
public struct MealPhotoOriginal: Sendable {
    public let data: Data
    public let exif: PhotoExif

    public init(data: Data, exif: PhotoExif) {
        self.data = data
        self.exif = exif
    }
}
