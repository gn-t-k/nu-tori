public import Foundation

/// 写真の撮影時刻（絶対時刻）と、その時刻の UTC との時差
public struct PhotoTakenTime: Hashable, Sendable {
    public let instant: Date
    public let utcOffsetSeconds: Int

    public init(instant: Date, utcOffsetSeconds: Int) {
        self.instant = instant
        self.utcOffsetSeconds = utcOffsetSeconds
    }

    /// 撮った時刻と、撮影時刻の無い写真の選んだ時刻。端末のタイムゾーンでのその時刻の時差にする
    public init(instant: Date, deviceTimeZone: TimeZone) {
        self.init(instant: instant, utcOffsetSeconds: deviceTimeZone.secondsFromGMT(for: instant))
    }

    /// 撮影時刻が無い、または暦に無い写真は、選んだ時刻にする
    public init(exif: PhotoExif, pickedAt: Date, deviceTimeZone: TimeZone) {
        switch exif {
        case .takenAt(let wallClock, let utcOffsetSeconds?):
            let instant = TimeZone(secondsFromGMT: utcOffsetSeconds).flatMap {
                Self.instant(of: wallClock, in: $0)
            }
            if let instant {
                self.init(instant: instant, utcOffsetSeconds: utcOffsetSeconds)
            } else {
                self.init(instant: pickedAt, deviceTimeZone: deviceTimeZone)
            }
        case .takenAt(let wallClock, nil):
            if let instant = Self.instant(of: wallClock, in: deviceTimeZone) {
                self.init(instant: instant, deviceTimeZone: deviceTimeZone)
            } else {
                self.init(instant: pickedAt, deviceTimeZone: deviceTimeZone)
            }
        case .none:
            self.init(instant: pickedAt, deviceTimeZone: deviceTimeZone)
        }
    }

    private static func instant(of wallClock: PhotoExif.WallClock, in timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: wallClock.year, month: wallClock.month, day: wallClock.day,
            hour: wallClock.hour, minute: wallClock.minute, second: wallClock.second
        )
        // 2月30日のような暦に無い日は、補正して別の日にせず nil にする
        guard components.isValidDate(in: calendar) else {
            return nil
        }
        return calendar.date(from: components)
    }
}
