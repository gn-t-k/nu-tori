import NuToriCore

/// バックグラウンドの送信ができるまでの置き場。消すものはまだ無い
nonisolated struct PlaceholderBackgroundTransferStore: BackgroundTransferStore {
    func cancelAndDeleteAll() async throws {}
}
