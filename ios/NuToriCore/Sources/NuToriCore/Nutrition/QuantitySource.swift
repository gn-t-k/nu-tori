/// 料理と材料の量の出どころ
public enum QuantitySource: Hashable, Sendable {
    /// 推定したまま。料理の量に比例させた材料の量も、これのまま
    case estimated
    /// 使う人が直した
    case corrected
}
