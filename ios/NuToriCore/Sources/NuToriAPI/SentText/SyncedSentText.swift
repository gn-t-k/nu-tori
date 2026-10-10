public import Foundation

/// 送った文章。作る書き込みで送る形と、取りに行く変更で届く形が同じ（作ったあと変わらない）
public struct SyncedSentText: Sendable, Equatable {
    public let id: UUID
    public let body: String
    /// 送る操作をした時刻
    public let sentAt: Date
    /// 送ったときのタイムゾーン
    public let timeZone: TimeZone

    public init(id: UUID, body: String, sentAt: Date, timeZone: TimeZone) {
        self.id = id
        self.body = body
        self.sentAt = sentAt
        self.timeZone = timeZone
    }
}
