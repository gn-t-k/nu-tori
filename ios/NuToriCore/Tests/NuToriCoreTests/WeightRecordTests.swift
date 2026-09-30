import NuToriCore
import Testing

@Suite("体重記録")
struct WeightRecordTests {
    @Suite("見せる時刻")
    struct ClockTimeOfRecord {
        let record: WeightRecord

        init() throws {
            record = try .manual(72.4, at: "2026-09-23T22:12:00Z", in: "Asia/Tokyo")
        }

        @Test("記録したときのタイムゾーンでの時計の時刻になること")
        func usesClockOfRecordedTimeZone() {
            #expect(record.clockTime == ClockTime(hour: 7, minute: 12))
        }
    }

    @Suite("出どころと時刻")
    struct SourceAndTimeLabel {
        @Suite("手で記録したとき")
        struct Manual {
            let record: WeightRecord

            init() throws {
                record = try .manual(72.4, at: "2026-09-24T07:12:00+09:00", in: "Asia/Tokyo")
            }

            @Test("手で記録と時刻になること")
            func labelsManualRecord() {
                #expect(record.sourceAndTimeLabel == "手で記録・7:12")
            }
        }

        @Suite("ヘルスケアから取り込んだとき")
        struct Imported {
            let record: WeightRecord

            init() throws {
                record = try .imported(71.8, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
            }

            @Test("アプリの名前と時刻になること")
            func labelsImportedRecord() {
                #expect(record.sourceAndTimeLabel == "体重計アプリ から・6:48")
            }
        }
    }

    @Suite("値を直す")
    struct CorrectingKilograms {
        let record: WeightRecord
        let replacingKilograms: Double

        init() throws {
            record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
            replacingKilograms = 71.86
        }

        @Test("取り込んだまま版を上げて0.1 kgに丸めること")
        func keepsImportedSourceAndBumpsVersion() throws {
            let corrected = try #require(record.correction(replacingKilograms: replacingKilograms))
            #expect(corrected.kilograms == 71.9)
            #expect(corrected.version == record.version + 1)
            #expect(corrected.id == record.id)
            #expect(corrected.instant == record.instant)
            #expect(corrected.timeZone == record.timeZone)
            #expect(corrected.inputSource == record.inputSource)
        }

        @Suite("範囲の下を外すとき")
        struct BelowRange {
            let record: WeightRecord
            let replacingKilograms: Double

            init() throws {
                record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                replacingKilograms = 19.94
            }

            @Test("直さないこと")
            func rejects() {
                #expect(record.correction(replacingKilograms: replacingKilograms) == nil)
            }
        }

        @Suite("範囲の上を外すとき")
        struct AboveRange {
            let record: WeightRecord
            let replacingKilograms: Double

            init() throws {
                record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                replacingKilograms = 300.1
            }

            @Test("直さないこと")
            func rejects() {
                #expect(record.correction(replacingKilograms: replacingKilograms) == nil)
            }
        }

        @Suite("丸めると範囲の下端に入るとき")
        struct RoundsOntoLowerBound {
            let record: WeightRecord
            let replacingKilograms: Double

            init() throws {
                record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                replacingKilograms = 19.96
            }

            @Test("20.0 kg に直ること")
            func correctsToLowerBound() throws {
                let corrected = try #require(
                    record.correction(replacingKilograms: replacingKilograms))
                #expect(corrected.kilograms == 20)
            }
        }

        @Suite("範囲の上端のとき")
        struct UpperBound {
            let record: WeightRecord
            let replacingKilograms: Double

            init() throws {
                record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                replacingKilograms = 300
            }

            @Test("300.0 kg に直ること")
            func correctsToUpperBound() throws {
                let corrected = try #require(
                    record.correction(replacingKilograms: replacingKilograms))
                #expect(corrected.kilograms == 300)
            }
        }

        @Suite("見せている値と同じとき")
        struct ShownValue {
            let record: WeightRecord
            let replacingKilograms: Double

            init() throws {
                record = try .imported(72.44, at: "2026-09-24T06:48:00+09:00", in: "Asia/Tokyo")
                replacingKilograms = 72.4
            }

            @Test("直さないこと")
            func leavesRecordUnchanged() {
                #expect(record.correction(replacingKilograms: replacingKilograms) == nil)
            }
        }
    }
}
