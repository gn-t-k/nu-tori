// shared/accepted-deadline-days.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

/// 期限として受け付ける、開始の日からの日数（両端を含む）
public enum AcceptedDeadlineDays {
    public static let minimum = 28
    public static let maximum = 182
}
