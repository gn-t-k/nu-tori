#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// UI テストの写真の送信。サーバーにつながず、送り始めた写真をすぐ受け取ったことにする
    nonisolated final class UITestMealPhotoUploader: MealPhotoUploader {
        let finishedUploads: AsyncStream<(MealPhotoUpload, MealPhotoUploadResult)>

        init() {
            let (finishedUploads, continuation) = AsyncStream.makeStream(
                of: (MealPhotoUpload, MealPhotoUploadResult).self)
            self.finishedUploads = finishedUploads
            self.continuation = continuation
        }

        func startUpload(_ upload: MealPhotoUpload, file: URL, request: MealPhotoUploadRequest)
            async
        {
            continuation.yield((upload, .responded(statusCode: 204)))
        }

        func uploadsInFlight() async -> Set<MealPhotoUpload> {
            []
        }

        func cancelUploads(ofMeal mealId: UUID) async {}

        func cancelAllUploads() async {}

        private let continuation: AsyncStream<(MealPhotoUpload, MealPhotoUploadResult)>.Continuation
    }
#endif
