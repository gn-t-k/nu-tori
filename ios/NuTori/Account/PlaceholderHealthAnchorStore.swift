import NuToriCore

/// ヘルスケアの取り込みができるまでの置き場。消すものはまだ無い
nonisolated struct PlaceholderHealthAnchorStore: HealthAnchorStore {
    func deleteAll() async throws {}
}
