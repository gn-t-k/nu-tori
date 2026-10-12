import Foundation
import NuToriCore
import Synchronization

/// 反映の先の差し替え。知らされたものを控える
final class RecordSyncReflectionMock: RecordSyncReflection, Sendable {
    /// 終えた同期の回数。同期は、終わりに着き先を知らせる
    let finishedSyncs = Tally()

    var destinations: [SignInDestination] {
        state.withLock { $0.destinations }
    }

    var undeliveredRecords: [UndeliveredRecords] {
        state.withLock { $0.undeliveredRecords }
    }

    static func ok() -> RecordSyncReflectionMock {
        RecordSyncReflectionMock()
    }

    func destinationChanged(_ destination: SignInDestination) async {
        state.withLock { $0.destinations.append(destination) }
        finishedSyncs.add()
    }

    func writesRejected(_ writes: [RejectedWrite]) async {}

    func recordReplacing(id recordId: UUID) async {}

    func unsentDishIdsChanged(_ unsentDishIds: Set<UUID>) async {}

    func undeliveredRecordsChanged(_ undeliveredRecords: UndeliveredRecords) async {
        state.withLock { $0.undeliveredRecords.append(undeliveredRecords) }
    }

    func replyStreamsChanged(_ streams: [UUID: ReplyStream]) async {}

    private struct State {
        var destinations: [SignInDestination] = []
        var undeliveredRecords: [UndeliveredRecords] = []
    }

    private let state = Mutex(State())

    private init() {}
}
