public import Foundation

/// 知らせ。端末が作り、答える。削除の印は持たない
public struct SyncedNotice: Sendable, Equatable {
    public let id: UUID
    public let noticeType: NoticeType
    public let issuedAt: Date
    public let timeZone: TimeZone
    /// 対象の日付（YYYY-MM-DD）
    public let targetOn: String
    /// 答えていなければ nil
    public let response: Response?

    public init(
        id: UUID,
        noticeType: NoticeType,
        issuedAt: Date,
        timeZone: TimeZone,
        targetOn: String,
        response: Response?
    ) {
        self.id = id
        self.noticeType = noticeType
        self.issuedAt = issuedAt
        self.timeZone = timeZone
        self.targetOn = targetOn
        self.response = response
    }

    /// サーバーの `noticeType` の値
    public enum NoticeType: String, Sendable, Equatable {
        /// 体重の記録忘れ
        case missedWeightRecord = "missed_weight_record"
    }

    /// 知らせへの答え
    public struct Response: Sendable, Equatable {
        public let respondedAt: Date
        public let timeZone: TimeZone

        public init(respondedAt: Date, timeZone: TimeZone) {
            self.respondedAt = respondedAt
            self.timeZone = timeZone
        }
    }
}
