/// EXIF を読むところ（アプリ側）が、読めた値のまま渡す形。決めるのは `PhotoTakenTime`
public enum PhotoExif: Hashable, Sendable {
    /// 撮影時刻（`DateTimeOriginal`）が無い。時差だけがあっても使わない
    case none
    /// 時差（`OffsetTimeOriginal`）は、撮った機器が書かないことがある
    case takenAt(WallClock, utcOffsetSeconds: Int?)

    /// EXIF の撮影時刻は、タイムゾーンを持たない時計の読み
    public struct WallClock: Hashable, Sendable {
        public let year: Int
        public let month: Int
        public let day: Int
        public let hour: Int
        public let minute: Int
        public let second: Int

        public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.second = second
        }
    }
}
