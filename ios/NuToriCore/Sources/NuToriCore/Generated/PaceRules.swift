// shared/pace.json から書き出した。直すときは JSON を直し、scripts/check ios --fix で書き出し直す

/// ペースの判定の係数
public enum PaceRules {
    /// 体重の傾向の動きを見る日数（判定する日を含む）。目標を立ててからこの日数たつまでは判定しない
    public static let windowDays = 14
    /// 言い切るのに要る、見る日数のうち体重記録のある日の数
    public static let minimumWeightRecordDayCount = 4
    /// 維持で、体重の傾向が収まっていればよい目標体重からの幅（±）
    public static let maintenanceBandKilograms = 0.7
}
