public import Foundation

/// 知らせを作る書き込みで送る値。答えは別の書き込み（`SyncWrite.respondNotice`）で送る
public struct NewNotice: Sendable, Equatable {
    public let id: UUID
    public let noticeType: SyncedNotice.NoticeType
    public let issuedAt: Date
    public let timeZone: TimeZone
    /// 対象の日付（YYYY-MM-DD）
    public let targetOn: String

    public init(
        id: UUID,
        noticeType: SyncedNotice.NoticeType,
        issuedAt: Date,
        timeZone: TimeZone,
        targetOn: String
    ) {
        self.id = id
        self.noticeType = noticeType
        self.issuedAt = issuedAt
        self.timeZone = timeZone
        self.targetOn = targetOn
    }
}
