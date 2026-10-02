public import NuToriAPI
import Synchronization

/// ビルド番号の扱いの差し替え。サーバーがこのビルドを受け付けたかの知らせを記録する
public final class AppBuildGateMock: Sendable {
    public let build: Int

    /// 受け取った知らせ。ミドルウェアと写真のアクターから並んで届くので、鍵をかけて持つ
    public var verdicts: [AppBuildVerdict] {
        recorded.withLock { $0 }
    }

    public static func ok(build: Int) -> AppBuildGateMock {
        AppBuildGateMock(build: build)
    }

    /// API のクライアントに渡すもの。知らせをこの差し替えに記録する
    public var gate: AppBuildGate {
        AppBuildGate(build: build) { verdict in
            self.recorded.withLock { $0.append(verdict) }
        }
    }

    private let recorded = Mutex<[AppBuildVerdict]>([])

    private init(build: Int) {
        self.build = build
    }
}
