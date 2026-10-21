// swift-tools-version: 6.4
// アプリのターゲットだけが使う依存の、版の正本。Xcode のプロジェクトの参照の version は、ここの exact: にそろえる（scripts/check ios が確かめる）
// ターゲットを持たない。NuToriCore に置くと、NuToriCore を解くたびに sentry-cocoa の xcframework（展開して約 3.1GB）を取るため（#606）
import PackageDescription

let package = Package(
    name: "AppDependencies",
    dependencies: [
        .package(url: "https://github.com/PostHog/posthog-ios.git", exact: "3.92.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", exact: "9.30.2"),
    ],
    targets: []
)
