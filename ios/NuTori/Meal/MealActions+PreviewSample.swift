#if DEBUG
    import UIKit

    extension MealActions {
        /// プレビューで押しても何もしない操作。カメラは無いものとして答え、カードの写真は見本の画像にする
        static var noop: MealActions {
            MealActions(
                prepareCamera: { .noCamera },
                recordCapturedPhoto: { _, _, _ in },
                recordPickedPhotos: { _, _ in },
                loadPhoto: { _, photoId in UIImage.sampleMealPhoto(for: photoId) }
            )
        }
    }
#endif
