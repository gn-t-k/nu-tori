public import Foundation

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
    /// 1回の撮る・選ぶで記録した食事。選んだ写真は、近い時刻ごとに複数の食事にまとまることがある
    case mealRecorded(entry: MealDraft.Entry, photoCount: Int, mealCount: Int)
    /// 標準のカメラを開いて、撮らずに閉じた
    case cameraCancelled
    /// カメラを許可していない人が「撮る」を押し、入力欄の上に知らせを出した
    case cameraPermissionNoticeShown
    /// 食事の画面で食事を消した。消したときのカードの状態と、送ってから消すまでの時間
    case mealDeleted(state: MealCardState, sinceRecorded: Duration)

    /// `now` は消した時刻。端末の時計が送った時刻より前なら、0 秒にする
    public static func mealDeleted(_ card: MealCard, at now: Date) -> ClientUsageEvent {
        .mealDeleted(
            state: card.state,
            sinceRecorded: .seconds(max(now.timeIntervalSince(card.meal.sentAt), 0)))
    }

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
        case meal
        case nutrientCitation
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
        case .mealRecorded: "meal_recorded"
        case .cameraCancelled: "camera_cancelled"
        case .cameraPermissionNoticeShown: "camera_permission_notice_shown"
        case .mealDeleted: "meal_deleted"
        }
    }

    public var screenToken: String? {
        switch self {
        case .weightRecorded, .weightCorrected, .weightInputCancelled, .usageDataTurnedOff,
            .initialPullDuration, .mealRecorded, .cameraCancelled, .cameraPermissionNoticeShown,
            .mealDeleted:
            nil
        case .screen(.timeline):
            "timeline"
        case .screen(.weight):
            "weight"
        case .screen(.weightEntry):
            "weight_entry"
        case .screen(.meal):
            "meal"
        case .screen(.nutrientCitation):
            "nutrient_citation"
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
        case .weightInputCancelled, .usageDataTurnedOff, .screen, .cameraCancelled,
            .cameraPermissionNoticeShown:
            [:]
        case .initialPullDuration(let duration):
            ["duration_seconds": .wholeSeconds(Self.wholeSeconds(duration))]
        case .mealRecorded(let entry, let photoCount, let mealCount):
            [
                "entry": .token(entry.token),
                "photo_count": .count(photoCount),
                "meal_count": .count(mealCount),
            ]
        case .mealDeleted(let state, let sinceRecorded):
            [
                "estimation_state": .token(state.token),
                "seconds_since_recorded": .wholeSeconds(Self.wholeSeconds(sinceRecorded)),
            ]
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

extension MealDraft.Entry {
    fileprivate var token: String {
        switch self {
        case .captured: "captured"
        case .picked: "picked"
        }
    }
}

extension MealCardState {
    fileprivate var token: String {
        switch self {
        case .notSent: "not_sent"
        case .awaitingPhotos: "awaiting_photos"
        case .estimating: "estimating"
        case .estimated: "estimated"
        case .noDishes: "no_dishes"
        case .deferredToNextDay: "deferred_to_next_day"
        case .failed: "failed"
        }
    }
}
