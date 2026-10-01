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

extension PhotoExif {
    /// EXIF の `DateTimeOriginal`（`2026:09:24 19:40:12`）と `OffsetTimeOriginal`（`+09:00`）の文字列から読む。
    /// 読めない撮影時刻と読めない時差は、無いものにする。暦に無い日かは `PhotoTakenTime` が見る
    public init(dateTimeOriginal: String?, offsetTimeOriginal: String?) {
        guard let dateTimeOriginal, let wallClock = Self.wallClock(from: dateTimeOriginal) else {
            self = .none
            return
        }
        self = .takenAt(
            wallClock, utcOffsetSeconds: offsetTimeOriginal.flatMap(Self.offsetSeconds(from:)))
    }

    private static func wallClock(from text: String) -> WallClock? {
        let parts = text.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2,
            let date = numbers(in: parts[0], digits: [4, 2, 2]),
            let time = numbers(in: parts[1], digits: [2, 2, 2])
        else {
            return nil
        }
        return WallClock(
            year: date[0], month: date[1], day: date[2],
            hour: time[0], minute: time[1], second: time[2])
    }

    private static func offsetSeconds(from text: String) -> Int? {
        guard let sign = text.first, sign == "+" || sign == "-",
            let hoursAndMinutes = numbers(in: text.dropFirst(), digits: [2, 2])
        else {
            return nil
        }
        let seconds = hoursAndMinutes[0] * 3600 + hoursAndMinutes[1] * 60
        return sign == "-" ? -seconds : seconds
    }

    /// `:` で区切った、決まった桁数の数字の並び。形が違えば nil
    private static func numbers(in text: Substring, digits: [Int]) -> [Int]? {
        let fields = text.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == digits.count else { return nil }
        var values: [Int] = []
        for (field, digitCount) in zip(fields, digits) {
            guard field.count == digitCount, field.allSatisfy({ $0.isASCII && $0.isNumber }),
                let value = Int(field)
            else {
                return nil
            }
            values.append(value)
        }
        return values
    }
}
