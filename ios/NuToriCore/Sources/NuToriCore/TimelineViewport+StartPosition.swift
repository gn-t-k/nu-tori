extension TimelineViewport {
    /// 並べたいちばん古い日の上端が、見えている所の上端にあるか
    public enum StartPosition: Equatable, Sendable {
        case atStart
        case belowStart

        /// - Parameters:
        ///   - contentOffsetY: スクロールの位置。上の帯に隠れた分だけ負になる
        ///   - topInset: 見えている所の上で、上の帯に隠れた高さ
        public init(contentOffsetY: Double, topInset: Double) {
            // 位置は小数で届くので、1 までのずれは上端ちょうどとみなす
            self = contentOffsetY <= 1 - topInset ? .atStart : .belowStart
        }
    }
}
