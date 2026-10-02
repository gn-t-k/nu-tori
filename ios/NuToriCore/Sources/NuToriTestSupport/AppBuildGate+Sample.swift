public import NuToriAPI

extension AppBuildGate {
    /// ビルド番号と締め出しを確かめないテストのための見本。知らせは捨てる
    public static let sample = AppBuildGate(build: 1, verdict: { _ in })
}
