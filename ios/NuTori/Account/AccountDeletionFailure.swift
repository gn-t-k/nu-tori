import NuToriCore

extension AccountDeletionFailure {
    var message: String {
        switch self {
        case .unreachable:
            "インターネットにつながらないため、削除できませんでした。つながるところで、もう一度押してください。"
        case .retryLater:
            "削除できませんでした。しばらくしてから、もう一度押してください。"
        }
    }
}
