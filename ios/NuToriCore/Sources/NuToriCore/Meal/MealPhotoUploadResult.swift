/// 裏で送った縮小版の結果
public enum MealPhotoUploadResult: Sendable {
    /// サーバーが答えた
    case responded(statusCode: Int)
    /// 答えを受け取れなかった（つながらない、時間切れ、取り消された、など）
    case failed(any Error)
}
