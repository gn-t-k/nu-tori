/// PostHog に送る端末の出来事。記録の中身と体重の値は持たない
public enum ClientUsageEvent: Sendable, Equatable {
    case weightRecorded(
        method: WeightInputMethod,
        stepperPressCount: Int,
        duration: Duration,
        showedTypoHint: Bool
    )
    case weightCorrected(WeightCorrectionPlace)
    case weightInputCancelled
    case usageDataTurnedOff
    case initialPullDuration(Duration)
    case screen(Screen)

    public enum WeightInputMethod: Sendable, Equatable {
        case stepper
        case keyboard
    }

    /// 体重の画面で確定したときの場所
    public enum WeightCorrectionPlace: Sendable, Equatable {
        case daySummary
        case otherRecords
        case recentRecords
    }

    public enum Screen: Sendable, Equatable {
        case timeline
        case weight
        case weightEntry
    }

    public enum Field: Sendable, Equatable {
        case count(Int)
        case wholeSeconds(Int)
        case flag(Bool)
        case token(String)
    }

    public var name: String {
        switch self {
        case .weightRecorded: "weight_recorded"
        case .weightCorrected: "weight_corrected"
        case .weightInputCancelled: "weight_input_cancelled"
        case .usageDataTurnedOff: "usage_data_turned_off"
        case .initialPullDuration: "initial_pull_duration"
        case .screen: "screen"
        }
    }

    public var screenToken: String? {
        guard case .screen(let screen) = self else { return nil }
        switch screen {
        case .timeline: return "timeline"
        case .weight: return "weight"
        case .weightEntry: return "weight_entry"
        }
    }

    public var fields: [String: Field] {
        switch self {
        case .weightRecorded(let method, let stepperPressCount, let duration, let showedTypoHint):
            [
                "method": .token(method.token),
                "stepper_press_count": .count(stepperPressCount),
                "duration_seconds": .wholeSeconds(Self.wholeSeconds(duration)),
                "showed_typo_hint": .flag(showedTypoHint),
            ]
        case .weightCorrected(let place):
            ["place": .token(place.token)]
        case .weightInputCancelled, .usageDataTurnedOff, .screen:
            [:]
        case .initialPullDuration(let duration):
            ["duration_seconds": .wholeSeconds(Self.wholeSeconds(duration))]
        }
    }

    private static func wholeSeconds(_ duration: Duration) -> Int {
        let seconds = duration.components.seconds
        return seconds > 0 ? Int(seconds) : 0
    }
}

extension ClientUsageEvent.WeightInputMethod {
    fileprivate var token: String {
        switch self {
        case .stepper: "stepper"
        case .keyboard: "keyboard"
        }
    }
}

extension ClientUsageEvent.WeightCorrectionPlace {
    fileprivate var token: String {
        switch self {
        case .daySummary: "day_summary"
        case .otherRecords: "other_records"
        case .recentRecords: "recent_records"
        }
    }
}
