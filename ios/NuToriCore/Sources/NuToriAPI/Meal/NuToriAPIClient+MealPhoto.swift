public import Foundation
import OpenAPIRuntime

extension NuToriAPIClient {
    /// 写真を持たない端末で、写真の控え（縮小版）を取りに行く
    public func fetchMealPhoto(id photoId: UUID) async throws -> FetchMealPhotoResult {
        let output = try await client.getMealPhoto(path: .init(photoId: photoId.canonicalString))
        switch output {
        case .ok(let ok):
            // サーバーが受け付ける写真は 3 MiB まで
            let maximumPhotoBytes = 3 * 1024 * 1024
            return .photo(try await Data(collecting: try ok.body.jpeg, upTo: maximumPhotoBytes))
        case .notFound:
            return .notFound
        case .unauthorized:
            return .sessionExpired
        case .tooManyRequests:
            return .rateLimited
        case .undocumented(let statusCode, _):
            throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 縮小版を送る要求。経路と状態コードは `server/openapi.json` の `putMealPhoto`。本文は縮小版の JPEG のファイルそのまま
    public func mealPhotoUploadRequest(photoId: UUID) async -> MealPhotoUploadRequest {
        var headerFields = [
            "Content-Type": "image/jpeg", AppBuildMiddleware.headerName: String(appBuildGate.build),
        ]
        if let token = await sessionToken() {
            headerFields["Authorization"] = "Bearer \(token)"
        }
        return MealPhotoUploadRequest(
            url: serverURL.appending(path: "v1/meal-photos/\(photoId.canonicalString)"),
            method: "PUT",
            headerFields: headerFields
        )
    }

    /// 縮小版を送った要求の応答を受け取ったときに呼ぶ。生成したクライアントを通さないので、ここでビルドを受け付けたかを知らせる
    public func receiveMealPhotoUploadResponse(statusCode: Int) async {
        await appBuildGate.receive(statusCode: statusCode)
    }

    public enum FetchMealPhotoResult: Sendable, Equatable {
        /// 縮小版の JPEG
        case photo(Data)
        /// まだ受け取っていないか、消した
        case notFound
        case sessionExpired
        case rateLimited
    }
}
