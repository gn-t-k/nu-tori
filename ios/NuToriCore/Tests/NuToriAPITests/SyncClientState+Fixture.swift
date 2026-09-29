import Foundation

@testable import NuToriAPI

extension SyncClientState {
    static func fixture() -> SyncClientState {
        SyncClientState(
            deviceId: UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!,
            appVersion: "1.0.0",
            osVersion: "26.0",
            pendingWriteCount: 2,
            oldestPendingWriteAge: .seconds(90),
            pendingPhotoCount: 0
        )
    }
}
