/// 消せなかったときは、端末では何も消さず、削除のまとまりの上に1行を出す
enum AccountDeletionFailure: Equatable {
    /// 電波が無いときと時間切れ
    case unreachable
    /// 回数の歯止め（429）とサーバーの失敗
    case retryLater

    var message: String {
        switch self {
        case .unreachable:
            "インターネットにつながらないため、削除できませんでした。つながるところで、もう一度押してください。"
        case .retryLater:
            "削除できませんでした。しばらくしてから、もう一度押してください。"
        }
    }
}
