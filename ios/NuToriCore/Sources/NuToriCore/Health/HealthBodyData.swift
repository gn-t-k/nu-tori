/// ヘルスケアから読めた身体データ。読めなかった値は nil で、足りない値として手で入れてもらう
public struct HealthBodyData: Sendable, Equatable {
    public let heightCentimeters: Double?
    public let age: Int?
    public let sex: BiologicalSex?
    /// 初期値の窓の日ごとの歩数。読めなかった日（サンプルが無い、読み取りの期間の境界より前）は入れない
    public let dailySteps: [CalendarDay: Int]

    public init(
        heightCentimeters: Double?,
        age: Int?,
        sex: BiologicalSex?,
        dailySteps: [CalendarDay: Int]
    ) {
        self.heightCentimeters = heightCentimeters
        self.age = age
        self.sex = sex
        self.dailySteps = dailySteps
    }
}
