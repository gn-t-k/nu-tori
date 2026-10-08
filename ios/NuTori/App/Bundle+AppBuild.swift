import Foundation

extension Bundle {
    /// アプリのビルド番号（`CFBundleVersion`）。Xcode Cloud がビルドごとに振り、開発用のビルドでは 1。
    /// 読めないときは、サーバーがヘッダーの無い要求とみなすのと同じ 0 にする
    nonisolated var appBuild: Int {
        (object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap { Int($0) } ?? 0
    }
}
