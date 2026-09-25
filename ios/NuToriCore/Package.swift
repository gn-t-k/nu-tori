// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NuToriCore",
    platforms: [
        .iOS(.v27),
        // ロジックのテストを Mac の上でも回すため
        .macOS(.v26),
    ],
    products: [
        .library(name: "NuToriCore", targets: ["NuToriCore"])
    ],
    targets: [
        .target(name: "NuToriCore", swiftSettings: strictSettings),
        .testTarget(
            name: "NuToriCoreTests",
            dependencies: ["NuToriCore"],
            swiftSettings: strictSettings
        ),
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
