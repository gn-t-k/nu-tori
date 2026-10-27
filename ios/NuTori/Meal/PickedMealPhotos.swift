import Foundation
import NuToriCore
import PhotosUI
import SwiftUI

/// 標準の写真を選ぶ画面で選んだ写真を、元のバイトと付帯情報で読む
enum PickedMealPhotos {
    /// 撮影時刻と時差を読むため、付帯情報つきの元のバイトで読む（ピッカーの `preferredItemEncoding` は `.current`）。
    /// iCloud にだけある写真は取りに行くので、選んでから食事のカードが出るまで待たせないよう、全部を同時に読む。並びは選んだ順のまま。読めなかった写真は飛ばす
    static func originals(of items: [PhotosPickerItem]) async -> [MealPhotoOriginal] {
        await withTaskGroup(of: (index: Int, original: Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    (index, try? await item.loadTransferable(type: Data.self))
                }
            }
            var originals: [Data?] = Array(repeating: nil, count: items.count)
            for await loaded in group {
                originals[loaded.index] = loaded.original
            }
            return originals.compactMap { $0 }.map(PhotoMetadata.mealPhotoOriginal(readingExifOf:))
        }
    }
}
