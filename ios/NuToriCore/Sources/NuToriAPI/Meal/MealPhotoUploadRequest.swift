public import Foundation

/// 写真の縮小版を送る要求。バックグラウンドの URLSession が送るので、生成したクライアントを通さずに組む
public struct MealPhotoUploadRequest: Sendable, Equatable {
    public let url: URL
    public let method: String
    public let headerFields: [String: String]

    public init(url: URL, method: String, headerFields: [String: String]) {
        self.url = url
        self.method = method
        self.headerFields = headerFields
    }
}
