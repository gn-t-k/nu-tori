import Foundation
import NuToriCore

/// 同期の段取りが知らせたことを、画面の状態（`RootModel`）に渡す。
/// 段取りを作るときに反映の先が要り、`RootModel` は段取りを受け取って作るので、あいだに置いて `RootModel` があとから受け取り方を入れる
// Sendable を求める protocol に従う型は、既定の MainActor の隔離が付かないので、型に明示し、protocol の関数からは MainActor に移る
@MainActor final class RecordSyncReflector: RecordSyncReflection {
    var onDestination: (SignInDestination) -> Void = { _ in }
    var onRejectedWrites: ([RejectedWrite]) -> Void = { _ in }
    var onReplacingRecord: (UUID) -> Void = { _ in }
    var onUnsentDishIds: (Set<UUID>) -> Void = { _ in }
    var onUndeliveredRecords: (UndeliveredRecords) -> Void = { _ in }
    var onReplyStreams: ([UUID: ReplyStream]) -> Void = { _ in }

    func destinationChanged(_ destination: SignInDestination) async {
        await MainActor.run { onDestination(destination) }
    }

    func writesRejected(_ writes: [RejectedWrite]) async {
        await MainActor.run { onRejectedWrites(writes) }
    }

    func recordReplacing(id recordId: UUID) async {
        await MainActor.run { onReplacingRecord(recordId) }
    }

    func unsentDishIdsChanged(_ unsentDishIds: Set<UUID>) async {
        await MainActor.run { onUnsentDishIds(unsentDishIds) }
    }

    func undeliveredRecordsChanged(_ undeliveredRecords: UndeliveredRecords) async {
        await MainActor.run { onUndeliveredRecords(undeliveredRecords) }
    }

    func replyStreamsChanged(_ streams: [UUID: ReplyStream]) async {
        await MainActor.run { onReplyStreams(streams) }
    }
}
