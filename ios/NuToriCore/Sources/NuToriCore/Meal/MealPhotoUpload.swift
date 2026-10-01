public import Foundation

/// 裏で送る写真の縮小版の1枚
public struct MealPhotoUpload: Hashable, Sendable {
    public let mealId: UUID
    public let photoId: UUID

    public init(mealId: UUID, photoId: UUID) {
        self.mealId = mealId
        self.photoId = photoId
    }

    /// 裏の送信に付ける名前から読む。アプリを開き直したあとに届いた結果と、送っている途中の送信を見分けるため
    public init?(taskDescription: String) {
        let parts = taskDescription.split(separator: "/")
        guard parts.count == 2,
            let mealId = UUID(uuidString: String(parts[0])),
            let photoId = UUID(uuidString: String(parts[1]))
        else {
            return nil
        }
        self.init(mealId: mealId, photoId: photoId)
    }

    /// 裏の送信に付ける名前
    public var taskDescription: String {
        "\(mealId.uuidString)/\(photoId.uuidString)"
    }
}
