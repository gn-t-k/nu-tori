public import NuToriAPI

/// ビルド番号の扱いの差し替え。サーバーがこのビルドを受け付けたかの知らせを記録する
public final class AppBuildGateMock: @unchecked Sendable {
    public let build: Int
    public private(set) var verdicts: [AppBuildVerdict] = []

    public static func ok(build: Int) -> AppBuildGateMock {
        AppBuildGateMock(build: build)
    }

    /// API のクライアントに渡すもの。知らせをこの差し替えに記録する
    public var gate: AppBuildGate {
        AppBuildGate(build: build) { self.verdicts.append($0) }
    }

    private init(build: Int) {
        self.build = build
    }
}
