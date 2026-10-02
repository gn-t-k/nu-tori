public import NuToriAPI

/// 体重の傾向の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct WeightTrendSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.weightTrend

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    /// キャッシュへの当て方。並び全体が届くので、日ごとに差し替えず、丸ごと置き換える
    public enum Update: Sendable, Equatable {
        /// 届いた並びで置き換える
        case replace(WeightTrend)
        /// 体重記録が1つも無くなった。キャッシュを空にする
        case clear
    }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 取りに行った変更のうち、最後に届いたものでの当て方。届いていなければ nil（キャッシュを変えない）。
    /// 日付が読めない日は読み飛ばす
    public func update(from changes: [SyncChange]) -> Update? {
        var latest: Update?
        for change in changes {
            if case .weightTrend(let synced) = change {
                latest = .replace(
                    WeightTrend(
                        days: synced.days.compactMap { day in
                            CalendarDay(yearMonthDay: day.calendarDay).map {
                                WeightTrend.Day(day: $0, kilograms: day.trendKilograms)
                            }
                        }))
            } else if case .weightTrendAbsence = change {
                latest = .clear
            }
        }
        return latest
    }
}
