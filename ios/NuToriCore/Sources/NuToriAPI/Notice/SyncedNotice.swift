public import Foundation

/// 知らせ。端末が作り、答える。削除の印は持たない
public struct SyncedNotice: Sendable, Equatable {
    public let id: UUID
    public let noticeType: NoticeType
    public let issuedAt: Date
    public let timeZone: TimeZone
    /// 答えていなければ nil
    public let response: Response?

    public init(
        id: UUID,
        noticeType: NoticeType,
        issuedAt: Date,
        timeZone: TimeZone,
        response: Response?
    ) {
        self.id = id
        self.noticeType = noticeType
        self.issuedAt = issuedAt
        self.timeZone = timeZone
        self.response = response
    }

    /// 知らせの種類。対象の日付は、記録忘れの知らせだけが持つ
    public enum NoticeType: Sendable, Equatable {
        /// 体重の記録忘れ。`targetOn` は対象の日付（YYYY-MM-DD）
        case missedWeightRecord(targetOn: String)
        /// 目標を立てる。1アカウントに1つ
        case goalSetup

        /// サーバーの `noticeType` の値
        public var serverName: String {
            switch self {
            case .missedWeightRecord: "missed_weight_record"
            case .goalSetup: "goal_setup"
            }
        }

        /// 対象の日付（YYYY-MM-DD）。記録忘れの知らせだけにある
        public var targetOn: String? {
            switch self {
            case .missedWeightRecord(let targetOn): targetOn
            case .goalSetup: nil
            }
        }

        /// 知らない種類と、対象の日付の無い記録忘れの知らせは nil。目標を立てる知らせに付いた対象の日付は読み飛ばす
        init?(serverName: String, targetOn: String?) {
            switch serverName {
            case "missed_weight_record":
                guard let targetOn else { return nil }
                self = .missedWeightRecord(targetOn: targetOn)
            case "goal_setup":
                self = .goalSetup
            // swiftlint:disable:next no_default_in_switch - サーバーの名前は文字列で、知らない値が来る
            default:
                return nil
            }
        }
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
