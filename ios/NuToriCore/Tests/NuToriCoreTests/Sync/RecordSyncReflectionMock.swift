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

    var appearances: [PendingAppearance] {
        state.withLock { $0.appearances }
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

    func pendingAppearanceChanged(_ appearance: PendingAppearance) async {
        state.withLock { $0.appearances.append(appearance) }
    }

    func replyStreamsChanged(_ streams: [UUID: ReplyStream]) async {}

    private struct State {
        var destinations: [SignInDestination] = []
        var appearances: [PendingAppearance] = []
    }

    private let state = Mutex(State())

    private init() {}
}
