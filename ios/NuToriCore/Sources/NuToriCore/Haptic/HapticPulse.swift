/// 値の変化からは決められないとき（編集が書けた）の触覚の合図。同じときが続いても値が変わるよう、鳴らした回数を持つ
public struct HapticPulse: Equatable, Sendable {
    /// 最後に鳴らしたとき。まだ何も鳴らしていないあいだは無い
    public private(set) var moment: HapticMoment?

    public init() {}

    public mutating func fire(_ moment: HapticMoment) {
        self.moment = moment
        count += 1
    }

    private var count = 0
}
