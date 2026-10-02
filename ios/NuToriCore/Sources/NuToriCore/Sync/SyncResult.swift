public struct SyncResult: Sendable, Equatable {
    public let rejectedWrites: [RejectedWrite]
    public let ending: Ending

    public init(rejectedWrites: [RejectedWrite], ending: Ending) {
        self.rejectedWrites = rejectedWrites
        self.ending = ending
    }

    public enum Ending: Sendable, Equatable {
        case finished
        case stopped(StopReason)
    }

    public enum StopReason: Sendable, Equatable {
        case rateLimited
        case sessionExpired
        case unavailable
        case badRequest
        /// サーバーが 426 を返した（締め出された）。送り待ちは結果を受け取っていないので残す
        case appBuildUnsupported
    }
}
