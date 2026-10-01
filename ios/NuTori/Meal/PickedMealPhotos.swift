import Foundation
import PhotosUI
import SwiftUI

/// 標準の写真を選ぶ画面で選んだ写真を、元のバイトで読む
enum PickedMealPhotos {
    /// 撮影時刻と時差を読むため、付帯情報つきの元のバイトで読む（ピッカーの `preferredItemEncoding` は `.current`）。
    /// 読めなかった写真は飛ばす
    static func originals(of items: [PhotosPickerItem]) async -> [Data] {
        var originals: [Data] = []
        for item in items {
            if let original = try? await item.loadTransferable(type: Data.self) {
                originals.append(original)
            }
        }
        return originals
    }
}
