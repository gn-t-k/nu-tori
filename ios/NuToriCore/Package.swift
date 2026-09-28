// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "NuToriCore",
    platforms: [
        .iOS(.v26),
        // ロジックのテストを Mac の上でも回すため
        .macOS(.v26),
    ],
    products: [
        .library(name: "NuToriCore", targets: ["NuToriCore"]),
        .library(name: "NuToriAPI", targets: ["NuToriAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.8.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.12.1"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.3.1"),
    ],
    targets: [
        .target(name: "NuToriCore", swiftSettings: strictSettings),
        .testTarget(
            name: "NuToriCoreTests",
            dependencies: ["NuToriCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "NuToriAPI",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "NuToriAPITests",
            dependencies: ["NuToriAPI"],
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
