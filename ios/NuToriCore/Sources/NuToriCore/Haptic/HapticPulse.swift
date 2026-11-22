/// 押した操作の触覚の合図。同じ操作を続けて押しても値が変わるよう、押した回数を持つ
public struct HapticPulse: Equatable, Sendable {
    /// 最後に押した操作。まだ何も押していないあいだは無い
    public private(set) var moment: HapticMoment?

    public init() {}

    public mutating func fire(_ moment: HapticMoment) {
        self.moment = moment
        count += 1
    }

    private var count = 0
}
