// swift-tools-version: 6.4
// 生成器を動かすためだけのパッケージ。アプリのビルドに生成器を入れないため、NuToriCore と分けた
import PackageDescription

let package = Package(
    name: "OpenAPIGenerator",
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.13.1")
    ]
)
