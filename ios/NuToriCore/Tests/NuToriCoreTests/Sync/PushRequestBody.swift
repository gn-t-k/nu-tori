import Foundation

struct PushRequestBody: Decodable {
    let writes: [Write]
    let isFinalBatch: Bool
    let clientState: ClientState

    struct Write: Decodable {
        let id: String
    }

    struct ClientState: Decodable {
        let deviceId: String
        let timeZone: String
        let pendingWriteCount: Int
        let oldestPendingWriteAgeSeconds: Int?
        let pendingPhotoCount: Int
    }
}
