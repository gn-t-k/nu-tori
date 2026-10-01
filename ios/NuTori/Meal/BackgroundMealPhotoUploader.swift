import Foundation
import NuToriAPI
import NuToriCore

/// 写真の縮小版を、バックグラウンドの URLSession で送る。アプリを裏に回しても送り続ける。
/// App スイッチャーで閉じると送信が取り消されるので、開いたときに `MealPhotos.resendPendingUploads` で送り直す
nonisolated final class BackgroundMealPhotoUploader: MealPhotoUploader {
    /// 送り終えた結果。アプリの中で `MealPhotos.finishUpload` に当てる
    let finishedUploads: AsyncStream<(MealPhotoUpload, MealPhotoUploadResult)>

    /// 前の起動で送り始めた送信の結果も受け取るため、起動のたびに同じ名前で作る
    init() {
        let (finishedUploads, continuation) = AsyncStream.makeStream(
            of: (MealPhotoUpload, MealPhotoUploadResult).self)
        self.finishedUploads = finishedUploads
        session = URLSession(
            configuration: .background(withIdentifier: "app.nu-tori.meal-photos"),
            delegate: CompletionDelegate(continuation: continuation),
            delegateQueue: nil
        )
    }

    func startUpload(_ upload: MealPhotoUpload, file: URL, request: MealPhotoUploadRequest) async {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (name, value) in request.headerFields {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let task = session.uploadTask(with: urlRequest, fromFile: file)
        task.taskDescription = upload.taskDescription
        task.resume()
    }

    func uploadsInFlight() async -> Set<MealPhotoUpload> {
        Set(await tasks().map { $0.upload })
    }

    func cancelUploads(ofMeal mealId: UUID) async {
        for (task, upload) in await tasks() where upload.mealId == mealId {
            task.cancel()
        }
    }

    func cancelAllUploads() async {
        for (task, _) in await tasks() {
            task.cancel()
        }
    }

    private let session: URLSession

    /// 送っている途中の送信と、その写真
    private func tasks() async -> [(task: URLSessionTask, upload: MealPhotoUpload)] {
        await session.allTasks.compactMap { task in
            switch task.state {
            case .running, .suspended:
                guard let description = task.taskDescription,
                    let upload = MealPhotoUpload(taskDescription: description)
                else { return nil }
                return (task: task, upload: upload)
            case .canceling, .completed:
                return nil
            @unknown default:
                return nil
            }
        }
    }

    // アプリのターゲットの既定は MainActor だが、URLSession は自分のキューから呼ぶ
    private nonisolated final class CompletionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
        init(continuation: AsyncStream<(MealPhotoUpload, MealPhotoUploadResult)>.Continuation) {
            self.continuation = continuation
        }

        func urlSession(
            _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
        ) {
            guard let description = task.taskDescription,
                let upload = MealPhotoUpload(taskDescription: description)
            else { return }
            continuation.yield((upload, Self.result(of: task, error: error)))
        }

        private let continuation: AsyncStream<(MealPhotoUpload, MealPhotoUploadResult)>.Continuation

        private static func result(of task: URLSessionTask, error: (any Error)?)
            -> MealPhotoUploadResult
        {
            if let error {
                return .failed(error)
            }
            // HTTP の要求の応答は HTTPURLResponse だが、URLSessionTask は URLResponse の型で返すので、確かめて取り出す
            guard let response = task.response as? HTTPURLResponse else {
                return .failed(URLError(.badServerResponse))
            }
            return .responded(statusCode: response.statusCode)
        }
    }
}
