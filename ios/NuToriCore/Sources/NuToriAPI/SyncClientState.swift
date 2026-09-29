public import Foundation

/// 送る要求と取りに行く要求に添える、端末の状態
public struct SyncClientState: Sendable, Equatable {
    public let deviceId: UUID
    public let timeZone: TimeZone
    public let appVersion: String
    public let osVersion: String
    public let pendingWriteCount: Int
    /// いちばん古い送り待ちの経過時間。送り待ちが無いときは nil
    public let oldestPendingWriteAge: Duration?
    public let pendingPhotoCount: Int

    public init(
        deviceId: UUID,
        timeZone: TimeZone,
        appVersion: String,
        osVersion: String,
        pendingWriteCount: Int,
        oldestPendingWriteAge: Duration?,
        pendingPhotoCount: Int
    ) {
        self.deviceId = deviceId
        self.timeZone = timeZone
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.pendingWriteCount = pendingWriteCount
        self.oldestPendingWriteAge = oldestPendingWriteAge
        self.pendingPhotoCount = pendingPhotoCount
    }
}
