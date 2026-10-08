#if DEBUG
    import UIKit

    extension MealActions {
        /// プレビューで押しても何もしない操作。カメラは無いものとして答え、カードの写真は見本の画像にする
        static var noop: MealActions {
            noop(loadPhoto: { _, photoId in UIImage.sampleMealPhoto(for: photoId) })
        }

        /// 写真をまだ持っていない端末の、押しても何もしない操作。写真は取りに行っても届かない
        static var noopWithoutPhotos: MealActions {
            noop(loadPhoto: { _, _ in nil })
        }

        private static func noop(
            loadPhoto: @escaping (_ mealId: UUID, _ photoId: UUID) async -> UIImage?
        ) -> MealActions {
            MealActions(
                prepareCamera: { .noCamera },
                recordCapturedPhoto: { _, _, _ in },
                recordPickedPhotos: { _, _ in },
                photoSelection: .picker,
                loadPhoto: loadPhoto,
                correctMealTime: { _, _ in },
                deleteMeal: { _, _ in },
                addDish: { _, _ in },
                dish: .noop
            )
        }
    }
#endif
