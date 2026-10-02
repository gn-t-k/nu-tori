public import Foundation

/// 知らせ。端末が作り、答える。消える道はアカウントの削除だけ
public struct Notice: Hashable, Sendable {
    /// 種類と対象の日付から作る ID（2台目も同じ日に同じ ID になる）
    public let id: UUID
    public let kind: Kind
    /// 出した時刻。通知の時刻（予約した時刻）で、気づいた時刻ではない
    public let issuedAt: Date
    /// 出したときのタイムゾーン
    public let timeZone: TimeZone
    /// 対象の日付
    public let targetDay: CalendarDay
    /// 答えていなければ nil。答えたあとに対象の日の体重記録を消しても、戻さない
    public let response: Response?

    public init(
        id: UUID,
        kind: Kind,
        issuedAt: Date,
        timeZone: TimeZone,
        targetDay: CalendarDay,
        response: Response?
    ) {
        self.id = id
        self.kind = kind
        self.issuedAt = issuedAt
        self.timeZone = timeZone
        self.targetDay = targetDay
        self.response = response
    }

    /// 種類と対象の日付から決まる UUID v5。2台目も同じ日に同じ ID になり、記録忘れの通知の予約の ID にも使う
    public static func id(kind: Kind, targetDay: CalendarDay) -> UUID {
        NameBasedUUID.version5(
            namespace: idNamespace, name: "\(kind.rawValue):\(targetDay.yearMonthDay)")
    }

    // 知らせの ID にだけ使う名前空間。変えると、同じ日の知らせが端末の版ごとに別の ID になる
    private static let idNamespace = UUID(uuidString: "C6E6CE2F-84F0-460C-BC4D-142C0B227A3A")!

    /// 知らせの種類。rawValue は送り待ちに保存する
    public enum Kind: String, Sendable {
        /// 体重の記録忘れ
        case missedWeightRecord = "missed-weight-record"
    }

    /// 知らせへの答え。答え方（知らせの中で記録した、ほかの経路で記録された）は持たない
    public struct Response: Hashable, Sendable {
        public let respondedAt: Date
        /// 答えたときのタイムゾーン
        public let timeZone: TimeZone

        public init(respondedAt: Date, timeZone: TimeZone) {
            self.respondedAt = respondedAt
            self.timeZone = timeZone
        }
    }

    /// 答えた形
    public func responded(_ response: Response) -> Notice {
        Notice(
            id: id, kind: kind, issuedAt: issuedAt, timeZone: timeZone, targetDay: targetDay,
            response: response)
    }
}
