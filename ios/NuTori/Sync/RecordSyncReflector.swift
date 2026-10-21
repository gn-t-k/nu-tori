import Foundation
import NuToriCore

/// 同期の段取りが知らせたことを、画面の状態（`RootModel`）に渡す。
/// 段取りを作るときに反映の先が要り、`RootModel` は段取りを受け取って作るので、あいだに置いて `RootModel` があとから受け取り方を入れる
// Sendable を求める protocol に従う型は、既定の MainActor の隔離が付かないので、型に明示する。
// 型に付けた隔離は、protocol の async の要求を満たす関数には付かない（プロパティを読むとコンパイルが止まる）ので、関数にも明示する
@MainActor final class RecordSyncReflector: RecordSyncReflection {
    var onDestination: (SignInDestination) -> Void = { _ in }
    var onRejectedWrites: ([RejectedWrite]) -> Void = { _ in }
    var onReplacingRecord: (UUID) -> Void = { _ in }
    var onPendingAppearance: (PendingAppearance) -> Void = { _ in }
    var onReplyStreams: ([UUID: ReplyStream]) -> Void = { _ in }

    @MainActor func destinationChanged(_ destination: SignInDestination) async {
        onDestination(destination)
    }

    @MainActor func writesRejected(_ writes: [RejectedWrite]) async {
        onRejectedWrites(writes)
    }

    @MainActor func recordReplacing(id recordId: UUID) async {
        onReplacingRecord(recordId)
    }

    @MainActor func pendingAppearanceChanged(_ appearance: PendingAppearance) async {
        onPendingAppearance(appearance)
    }

    @MainActor func replyStreamsChanged(_ streams: [UUID: ReplyStream]) async {
        onReplyStreams(streams)
    }
}
