import Foundation
import NuToriAPI
import NuToriCore

/// 裏の送信の差し替え。送り始めた写真と取り消しを記録し、送っている途中の写真を持つ
final class MealPhotoUploaderMock: MealPhotoUploader, @unchecked Sendable {
    struct Started: Equatable {
        let upload: MealPhotoUpload
        let file: URL
        let request: MealPhotoUploadRequest
    }

    private(set) var started: [Started] = []
    private(set) var cancelledMealIds: [UUID] = []
    private(set) var cancelAllCount = 0
    private(set) var inFlight: Set<MealPhotoUpload> = []

    /// 送信に失敗のしかたは無い（結果は `MealPhotos.finishUpload` に届く）ので、作り方は ok だけ
    static func ok() -> MealPhotoUploaderMock {
        MealPhotoUploaderMock()
    }

    /// App スイッチャーで閉じたときのように、送っている途中の送信がすべて無くなる
    func dropAllInFlight() {
        inFlight = []
    }

    /// 送り終えて、送っている途中から外れる
    func finish(_ upload: MealPhotoUpload) {
        inFlight.remove(upload)
    }

    func startUpload(_ upload: MealPhotoUpload, file: URL, request: MealPhotoUploadRequest) async {
        started.append(Started(upload: upload, file: file, request: request))
        inFlight.insert(upload)
    }

    func uploadsInFlight() async -> Set<MealPhotoUpload> {
        inFlight
    }

    func cancelUploads(ofMeal mealId: UUID) async {
        cancelledMealIds.append(mealId)
        inFlight = inFlight.filter { $0.mealId != mealId }
    }

    func cancelAllUploads() async {
        cancelAllCount += 1
        inFlight = []
    }

    private init() {}
}
