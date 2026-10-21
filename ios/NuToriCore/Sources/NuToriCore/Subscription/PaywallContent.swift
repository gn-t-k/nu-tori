import Foundation

/// 課金画面のうち自前で書く部分（宣伝の部分とまとめ）の文。
/// 価格・期間・購入・購入を復元・規約のリンクは StoreKit の `SubscriptionStoreView` が描くので、ここに持たない
public struct PaywallContent: Equatable, Sendable {
    /// 宣伝の部分の見出し
    public let headline: String
    /// まとめの「支払いが始まる日」。サブスクリプション中（月額と年額の切り替え）は、始まる日が切り替え方で変わるので書かない
    public let paymentStart: String?
    /// まとめの「自動更新」
    public let renewal = "解約しない限り、自動で更新します。"
    /// 「自動更新」の下に箇条書きで並べる、月額・年額の更新の間隔と次の更新日。
    /// サブスクリプション中（月額と年額の切り替え）は、次の更新日が切り替え方で変わるので書かない
    public let renewalSchedule: [String]

    /// テストユーザーは課金画面を開かないので nil
    public init?(standing: SubscriptionStanding, today: CalendarDay) {
        let schedule = [
            "月額を選んだ場合: 1か月ごと（次は\(GoalText.monthDay(Self.adding(months: 1, to: today)))）",
            "年額を選んだ場合: 1年ごと（次は\(Self.yearMonthDay(Self.adding(months: 12, to: today)))）",
        ]
        switch standing {
        case .testUser:
            return nil
        case .freeTrial(_, let remainingDays):
            headline = Self.freeTrialHeadline
            paymentStart = "今日から。無料体験の残り \(remainingDays) 日はなくなります"
            renewalSchedule = schedule
        case .expired:
            headline = "撮って記録するには、サブスクリプションが必要です"
            paymentStart = "今日から"
            renewalSchedule = schedule
        case .subscribed:
            headline = Self.freeTrialHeadline
            paymentStart = nil
            renewalSchedule = []
        }
    }

    /// 使えるもの
    public static let features = [
        "撮った写真から、料理と量を推定する",
        "体重の傾向と食べた量から、1日の目安を見直す",
        "書いた文に返事をする",
    ]

    /// 使えるものに添える1行
    public static let keepsWithoutSubscription =
        "体重の記録と傾向、これまでの記録の見返しは、サブスクリプションが無くてもずっとできます。"

    /// まとめの「解約の方法」
    public static let cancellation =
        "iPhone の設定 → Apple アカウント → サブスクリプションから。更新日の24時間前までに解約すれば次の請求はありません"

    private static let freeTrialHeadline = "撮るだけで、1日の目安が体に合っていく"

    /// 次の月に同じ日が無ければ、その月の終わりの日にする（App Store の更新日と同じ）
    private static func adding(months: Int, to day: CalendarDay) -> CalendarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(
            from: DateComponents(year: day.year, month: day.month, day: day.day))!
        let added = calendar.date(byAdding: .month, value: months, to: start)!
        return CalendarDay(containing: added, utcOffsetSeconds: 0)
    }

    /// 「2027年10月21日」
    private static func yearMonthDay(_ day: CalendarDay) -> String {
        "\(day.year)年\(GoalText.monthDay(day))"
    }
}
