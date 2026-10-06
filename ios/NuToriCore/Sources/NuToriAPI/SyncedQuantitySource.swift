/// 料理と材料の量の出どころ。サーバーの `quantitySource` の値
public enum SyncedQuantitySource: String, Sendable, Equatable {
    /// 推定したまま。料理の量に比例させた材料の量も、これのまま
    case estimated
    /// 使う人が直した
    case corrected
}
