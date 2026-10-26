/// 体重の画面の「最近の記録」と、その先の「すべての記録」。使い始めた日からの記録を、新しい順に1日1つ並べる。
/// 使い始める前のヘルスケアの記録は並べない（ヘルスケアアプリで見られる。傾向のグラフには薄い点で残る）
public struct RecentWeightRecords: Sendable {
    /// 体重の画面に並べる、新しい日から5日
    public let latest: [RepresentativeWeight]
    /// 「すべての記録」に並べる、記録のある全部の日
    public let all: [RepresentativeWeight]

    public init(weightRecords: [WeightRecord], firstDay: CalendarDay) {
        all = RepresentativeWeight.daily(of: weightRecords.filter { $0.day >= firstDay }).reversed()
        latest = Array(all.prefix(Self.latestDayCount))
    }

    /// 体重の画面に並べきれない日があり、「すべての記録」への行を置くか
    public var hasMore: Bool { all.count > latest.count }

    private static let latestDayCount = 5
}
