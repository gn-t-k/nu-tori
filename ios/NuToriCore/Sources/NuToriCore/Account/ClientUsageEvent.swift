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
    /// 食事の画面で食事を消した。消したときの推定の状態と、送ってから消すまでの時間
    case mealDeleted(status: MealEstimationStatus, sinceRecorded: Duration)
    /// 食事の画面で時刻を直した。回数だけを数え、時刻は載せない
    case mealTimeCorrected
    /// 料理の画面で料理の名前・量か材料の量を直した。回数だけを数え、名前と量は載せない
    case dishCorrected
    /// 食事の画面の「料理を足す」で料理を足した。回数だけを数え、名前は載せない
    case dishAdded
    /// 料理を消した（食事の画面で左へ送った、料理の画面の「この料理を削除」）。最後の1品で食事ごと消したときは数えない
    case dishDeleted
    /// 帯の下の、答えていない知らせの1行を押した
    case unansweredNoticeLineTapped
    /// 記録忘れの通知を押して開いた。着いたときに、その日の体重の知らせがあったか
    case missedWeightReminderOpened(hadNotice: Bool)
    /// この端末で初めて体重を記録したあとに、通知の許可を求めた
    case notificationPermissionRequested(granted: Bool)
    /// アカウントの画面の通知の行から、iPhone の設定を開いた
    case notificationSettingsOpened

    /// `now` は消した時刻。端末の時計が送った時刻より前なら、0 秒にする。
    /// 推定の状態がまだ届いていない食事は、サーバーで予定がまだ無いので、写真を待っているとして送る
    public static func mealDeleted(_ card: MealCard, at now: Date) -> ClientUsageEvent {
        .mealDeleted(
            status: card.status ?? .awaitingPhotos,
            sinceRecorded: .seconds(max(now.timeIntervalSince(card.meal.sentAt), 0)))
    }

    public enum WeightInputMethod: Sendable, Equatable {
        case stepper
        case keyboard
        /// 体重の知らせの中で記録した
        case notice
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
        case .mealTimeCorrected: "meal_time_corrected"
        case .dishCorrected: "dish_corrected"
        case .dishAdded: "dish_added"
        case .dishDeleted: "dish_deleted"
        case .unansweredNoticeLineTapped: "unanswered_notice_line_tapped"
        case .missedWeightReminderOpened: "missed_weight_reminder_opened"
        case .notificationPermissionRequested: "notification_permission_requested"
        case .notificationSettingsOpened: "notification_settings_opened"
        }
    }

    public var screenToken: String? {
        switch self {
        case .weightRecorded, .weightCorrected, .weightInputCancelled, .usageDataTurnedOff,
            .initialPullDuration, .mealRecorded, .cameraCancelled, .cameraPermissionNoticeShown,
            .mealDeleted, .mealTimeCorrected, .dishCorrected, .dishAdded, .dishDeleted,
            .unansweredNoticeLineTapped,
            .missedWeightReminderOpened,
            .notificationPermissionRequested, .notificationSettingsOpened:
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
            .cameraPermissionNoticeShown, .mealTimeCorrected, .dishCorrected, .dishAdded,
            .dishDeleted,
            .unansweredNoticeLineTapped,
            .notificationSettingsOpened:
            [:]
        case .missedWeightReminderOpened(let hadNotice):
            ["had_notice": .flag(hadNotice)]
        case .notificationPermissionRequested(let granted):
            ["granted": .flag(granted)]
        case .initialPullDuration(let duration):
            ["duration_seconds": .wholeSeconds(Self.wholeSeconds(duration))]
        case .mealRecorded(let entry, let photoCount, let mealCount):
            [
                "entry": .token(entry.token),
                "photo_count": .count(photoCount),
                "meal_count": .count(mealCount),
            ]
        case .mealDeleted(let status, let sinceRecorded):
            [
                "estimation_state": .token(status.token),
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
        case .notice: "notice"
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

extension MealEstimationStatus {
    fileprivate var token: String {
        switch self {
        case .awaitingPhotos: "awaiting_photos"
        case .estimating: "estimating"
        case .estimated: "estimated"
        case .noDishes: "no_dishes"
        case .deferredToNextDay: "deferred_to_next_day"
        case .failed: "failed"
        }
    }
}
