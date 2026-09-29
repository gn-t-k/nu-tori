// swift-tools-version: 6.4
// 生成器を動かすためだけのパッケージ。アプリのビルドに生成器を入れないため、NuToriCore と分けた
import PackageDescription

let package = Package(
    name: "SharedRulesGenerator",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "SharedRulesGenerator", swiftSettings: strictSettings)
    ],
    swiftLanguageModes: [.v6]
)

var strictSettings: [SwiftSetting] {
    [
        .treatAllWarnings(as: .error),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("ImmutableWeakCaptures"),
    ]
}
