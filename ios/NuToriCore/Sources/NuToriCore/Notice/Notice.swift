public import Foundation

/// 知らせ。端末が作り、答える。消える道はアカウントの削除だけ
public struct Notice: Hashable, Sendable {
    /// 種類（と、記録忘れの知らせは対象の日付）から作る ID（2台目も同じ ID になる）
    public let id: UUID
    /// 対象の日付は、記録忘れの知らせの種類が持つ
    public let kind: Kind
    /// 出した時刻。通知の時刻（予約した時刻）で、気づいた時刻ではない
    public let issuedAt: Date
    /// 出したときのタイムゾーン
    public let timeZone: TimeZone
    /// 答えていなければ nil。答えたあとに対象の日の体重記録を消しても、戻さない
    public let response: Response?

    public init(
        id: UUID,
        kind: Kind,
        issuedAt: Date,
        timeZone: TimeZone,
        response: Response?
    ) {
        self.id = id
        self.kind = kind
        self.issuedAt = issuedAt
        self.timeZone = timeZone
        self.response = response
    }

    /// 対象の日付。記録忘れの知らせだけにある
    public var targetDay: CalendarDay? {
        kind.targetDay
    }

    /// 種類から決まる UUID v5。記録忘れの知らせは対象の日付ごと、目標を立てる知らせは1アカウントに1つ。
    /// 2台目も同じ ID になり、記録忘れの知らせの ID は通知の予約の ID にも使う
    public static func id(of kind: Kind) -> UUID {
        let name =
            switch kind {
            case .missedWeightRecord(let targetDay):
                "\(kind.storedName):\(targetDay.yearMonthDay)"
            case .goalSetup: kind.storedName
            }
        return NameBasedUUID.version5(namespace: idNamespace, name: name)
    }

    // 知らせの ID にだけ使う名前空間。変えると、同じ知らせが端末の版ごとに別の ID になる
    private static let idNamespace = UUID(uuidString: "C6E6CE2F-84F0-460C-BC4D-142C0B227A3A")!

    /// 知らせの種類
    public enum Kind: Hashable, Sendable {
        /// 体重の記録忘れ。対象の日付を持つ
        case missedWeightRecord(targetDay: CalendarDay)
        /// 目標を立てる。対象の日付を持たない
        case goalSetup

        /// 送り待ちとキャッシュに保存する名前。変えると、保存した知らせが読めなくなり、知らせの ID も変わる
        public var storedName: String {
            switch self {
            case .missedWeightRecord: "missed-weight-record"
            case .goalSetup: "goal-setup"
            }
        }

        /// 対象の日付。記録忘れの知らせだけにある
        public var targetDay: CalendarDay? {
            switch self {
            case .missedWeightRecord(let targetDay): targetDay
            case .goalSetup: nil
            }
        }

        /// 保存した名前と対象の日付から読む。知らない名前と、対象の日付の無い記録忘れの知らせは nil
        public init?(storedName: String, targetDay: CalendarDay?) {
            switch storedName {
            case "missed-weight-record":
                guard let targetDay else { return nil }
                self = .missedWeightRecord(targetDay: targetDay)
            case "goal-setup":
                self = .goalSetup
            default:
                return nil
            }
        }
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
        Notice(id: id, kind: kind, issuedAt: issuedAt, timeZone: timeZone, response: response)
    }
}
