public import NuToriAPI
public import Observation

/// 締め出しの記憶。サーバーが最低バージョンより古いビルドに 426 を返したら覚え、締め出しの画面はこの状態を見て全面を覆う。
/// 端末に置く理由は、電波が無いと締め出されたことが見えず、古い版で記録を書き足してしまうため（ルートの `AGENTS.md` の基準1）
@MainActor
@Observable
public final class AppLockout {
    /// 締め出されているか
    public private(set) var isLockedOut: Bool

    /// 覚えたビルド番号が今と同じなら、要求を待たずに締め出された状態で始める。変わっていたら（更新した）忘れる
    public init(currentBuild: Int, store: any AppLockoutStore) {
        self.currentBuild = currentBuild
        self.store = store
        switch store.lockedOutBuild() {
        case currentBuild?:
            isLockedOut = true
        case nil:
            isLockedOut = false
        case _?:
            store.forget()
            isLockedOut = false
        }
    }

    /// API のクライアントが応答を受け取るたびに呼ぶ（`NuToriAPIClient` に渡す `AppBuildGate` の `verdict`）。
    /// 426 なら覚え、426 でない応答なら忘れる（最低バージョンを下げた日のため）
    public func receive(_ verdict: AppBuildVerdict) {
        switch verdict {
        case .unsupported:
            store.remember(lockedOutBuild: currentBuild)
            isLockedOut = true
        case .supported:
            if store.lockedOutBuild() != nil {
                store.forget()
            }
            isLockedOut = false
        }
    }

    private let currentBuild: Int
    @ObservationIgnored private let store: any AppLockoutStore
}
