import Foundation
import NuToriCore

extension UserEdit {
    /// 2026-09-22 12:10（東京）に撮り、1分後に送った昼の食事を、元の写真 `original` で記録する。
    /// 撮った時刻は写真の付帯情報から読み、`MealDraft.lunch` と同じ時刻・時差の食事になる
    static func recordingCapturedAtLunch(_ original: Data) -> UserEdit {
        .recordCapturedMeal(
            MealPhotoOriginal(
                data: original,
                exif: .takenAt(
                    PhotoExif.WallClock(
                        year: 2026, month: 9, day: 22, hour: 12, minute: 10, second: 0),
                    utcOffsetSeconds: 32_400)),
            sentAt: Date(timeIntervalSince1970: 1_790_046_660))
    }
}
