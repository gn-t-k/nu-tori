public import Foundation

public struct SyncDevice: Sendable, Equatable {
    public let deviceId: UUID
    public let appVersion: String
    public let osVersion: String

    public init(deviceId: UUID, appVersion: String, osVersion: String) {
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.osVersion = osVersion
    }
}
