import Foundation

struct PushRequestBody: Decodable {
    let writes: [Write]
    let isFinalBatch: Bool
    let clientState: ClientState

    struct Write: Decodable {
        let id: String
        let type: String
        let accountSettings: AccountSettings?

        struct AccountSettings: Decodable, Equatable {
            let id: String
            let sendsUsageData: Bool
        }
    }

    struct ClientState: Decodable {
        let deviceId: String
        let timeZone: String
        let pendingWriteCount: Int
        let oldestPendingWriteAgeSeconds: Int?
        let pendingPhotoCount: Int
    }
}
