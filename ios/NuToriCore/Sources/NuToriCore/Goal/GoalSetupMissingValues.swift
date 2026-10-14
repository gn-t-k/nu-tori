public import NuToriAPI

/// 足りない値のページ。逆算できない人に、ヘルスケアから取れなかった値だけを尋ねる。
/// 値は端末の中だけに持ち、目標が決まったら捨てる
public struct GoalSetupMissingValues: Sendable, Equatable {
    /// 尋ねる値。ページに出す欄の並び
    public let asked: [Field]
    public let entry: Entry
    /// 生まれた年で選べる年（年齢が受け付ける範囲に入る年だけ）
    public let selectableBirthYears: ClosedRange<Int>

    /// - Parameter asksCurrentWeight: 体重の記録が1つも無い人だけ、今の体重を尋ねる
    init(health: HealthBodyData, asksCurrentWeight: Bool, today: CalendarDay) {
        self.health = health
        self.today = today
        var asked: [Field] = []
        if health.heightCentimeters.map({ !AcceptedRange.heightCentimeters.bounds.contains($0) })
            ?? true
        {
            asked.append(.height)
        }
        if health.age.map({ !AcceptedRange.ageYears.bounds.contains(Double($0)) }) ?? true {
            asked.append(.birthYear)
        }
        if health.sex == nil {
            asked.append(.sex)
        }
        if health.dailySteps.isEmpty {
            asked.append(.activityLevel)
        }
        if asksCurrentWeight {
            asked.append(.currentWeight)
        }
        self.asked = asked
        entry = Entry(
            heightCentimeters: nil, birthYear: nil, sex: nil, activityLevel: nil,
            currentWeightKilograms: nil)
        let ages = AcceptedRange.ageYears.bounds
        selectableBirthYears = (today.year - Int(ages.upperBound))...(today.year - Int(ages.lowerBound))
    }

    private init(replacing values: GoalSetupMissingValues, entry: Entry) {
        asked = values.asked
        selectableBirthYears = values.selectableBirthYears
        health = values.health
        today = values.today
        self.entry = entry
    }

    func entering(_ entry: Entry) -> GoalSetupMissingValues {
        GoalSetupMissingValues(replacing: self, entry: entry)
    }

    /// 尋ねた値がそろい、どれも受け付ける範囲に入っているか。そうでなければ「次へ」を押せない
    public var isComplete: Bool {
        body != nil && (!asked.contains(.currentWeight) || currentWeightKilograms != nil)
    }

    /// 体重の記録が無い人が入れた今の体重。受け付ける範囲の外なら nil
    var currentWeightKilograms: Double? {
        entry.currentWeightKilograms.flatMap {
            AcceptedRange.weightKilograms.bounds.contains($0) ? $0 : nil
        }
    }

    /// ヘルスケアから読めた値と入れた値を合わせた身体データ。足りなければ nil
    var body: GoalSetupBody? {
        let height = asked.contains(.height) ? entry.heightCentimeters : health.heightCentimeters
        let age = asked.contains(.birthYear) ? enteredAge : health.age
        let sex = asked.contains(.sex) ? entry.sex : health.sex.map(GoalSetupBody.Sex.init)
        guard let height, AcceptedRange.heightCentimeters.bounds.contains(height), let age, let sex
        else { return nil }
        let activity: GoalSetupBody.Activity
        if asked.contains(.activityLevel) {
            guard let level = entry.activityLevel else { return nil }
            activity = .level(level)
        } else {
            activity = .steps(
                Dictionary(
                    uniqueKeysWithValues: health.dailySteps.map { ($0.key.yearMonthDay, $0.value) }))
        }
        return GoalSetupBody(sex: sex, heightCentimeters: height, ageYears: age, activity: activity)
    }

    /// 手で入れた生まれた年は、今年との差にする。選べない年なら nil
    private var enteredAge: Int? {
        guard let year = entry.birthYear, selectableBirthYears.contains(year) else { return nil }
        return AgeInYears.approximate(bornInYear: year, on: today)
    }

    public enum Field: Sendable, Equatable {
        case height
        case birthYear
        case sex
        /// 活動量の3択。歩数が読めなかったときだけ尋ねる
        case activityLevel
        case currentWeight
    }

    /// 入れた値。入れていない欄は nil
    public struct Entry: Sendable, Equatable {
        public let heightCentimeters: Double?
        public let birthYear: Int?
        public let sex: GoalSetupBody.Sex?
        public let activityLevel: GoalSetupBody.Level?
        public let currentWeightKilograms: Double?

        public init(
            heightCentimeters: Double?,
            birthYear: Int?,
            sex: GoalSetupBody.Sex?,
            activityLevel: GoalSetupBody.Level?,
            currentWeightKilograms: Double?
        ) {
            self.heightCentimeters = heightCentimeters
            self.birthYear = birthYear
            self.sex = sex
            self.activityLevel = activityLevel
            self.currentWeightKilograms = currentWeightKilograms
        }
    }

    private let health: HealthBodyData
    private let today: CalendarDay
}

extension GoalSetupBody.Sex {
    fileprivate init(_ sex: BiologicalSex) {
        switch sex {
        case .male: self = .male
        case .female: self = .female
        }
    }
}
