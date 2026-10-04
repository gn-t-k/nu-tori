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
        .package(url: "https://github.com/apple/swift-crypto", exact: "5.0.0"),
        // 版の正本をここに置く。アプリのターゲットだけが import し、このパッケージのターゲットは依存しない
        .package(url: "https://github.com/PostHog/posthog-ios.git", exact: "3.85.3"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", exact: "9.29.2"),
    ],
    targets: [
        .target(
            name: "NuToriCore",
            dependencies: [
                "NuToriAPI",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "NuToriCoreTests",
            dependencies: [
                "NuToriCore",
                "NuToriAPI",
                "NuToriTestSupport",
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            swiftSettings: strictSettings
        ),
        // テストが使う差し替え（API のトランスポート、メモリの送り待ちの箱）。アプリのターゲットは依存しない
        .target(
            name: "NuToriTestSupport",
            dependencies: [
                "NuToriCore",
                "NuToriAPI",
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
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
            dependencies: [
                "NuToriAPI",
                "NuToriTestSupport",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
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
