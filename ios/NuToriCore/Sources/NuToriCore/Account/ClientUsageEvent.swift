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
    /// 入力欄から文章を送った。本文は載せない。`preset` は押したプリセット（使っていなければ nil）、`length` は前後の空白を除いた字数
    case textSent(preset: TextPreset?, editedPreset: Bool, length: Int)
    /// 入力欄の上のプリセットを押した
    case presetTapped(TextPreset)
    /// 文章の食事のカードの「会話として送り直す」を押した。その場で消えた食事の数
    case resentAsConversation(deletedMealCount: Int)
    /// 作れなかった・回数切れの1行の「送り直す」を押した。押したときの1行の理由
    case replyRegenerateTapped(ReplyRegenerateReason)
    /// 返事の最初の文字を出した。応答を待ち始めてから出るまでの時間と、見守る要求で届いた（つながっていた）か
    case replyFirstTextShown(sinceSent: Duration, watched: Bool)
    /// 返事の下の、指し示す食事の行を押した
    case replyMealOpened
    /// 目標の設定を開いた・閉じた・決めた・案を1つも出せなかった。体重・目標体重・kcal と身体データは載せない
    case goalSetup(GoalSetupObservation)
    /// 週の振り返りを開いた。‹ › で週を送ったときも送る。`weeksAgo` は今日を含む週から何週前の週か
    case weeklyReviewOpened(entry: WeeklyReviewEntry, weeksAgo: Int)
    /// 目標の画面を開いた
    case goalScreenOpened(entry: GoalScreenEntry, status: GoalScreenStatus)
    /// 開いたときに、規約への同意のシートを出した
    case termsAgreementSheetShown
    /// 同意のシートの「同意して続ける」で、同意を受け付けられた
    case termsAgreed
    /// サブスクリプション中に「アカウントを削除」を押し、退会の案内のシートを出した
    case accountDeletionGuideOpened
    /// 退会の案内のシートの「サブスクリプションを解約」で、解約の画面を開いた
    case manageSubscriptionsOpened

    /// `now` は消した時刻。端末の時計が送った時刻より前なら、0 秒にする。
    /// 推定の状態がまだ届いていない食事は、サーバーで予定がまだ無いので、写真を待っているとして送る
    public static func mealDeleted(_ card: MealCard, at now: Date) -> ClientUsageEvent {
        .mealDeleted(
            status: card.status ?? .awaitingPhotos,
            sinceRecorded: .seconds(max(now.timeIntervalSince(card.meal.sentAt), 0)))
    }

    /// 「送り直す」を添えた1行の理由
    public enum ReplyRegenerateReason: Sendable, Equatable {
        case failed(SentTextStatus.FailureReason)
        case halted
    }

    /// 週の振り返りを開いたところ
    public enum WeeklyReviewEntry: Sendable, Equatable, Hashable {
        /// タイムラインの振り返りのカード
        case weeklyReviewCard
        /// 目標の画面の週の振り返りへの1行
        case goalScreen
        /// 日のまとめの週の振り返りの行
        case daySummary
    }

    /// 目標の画面を開いたところ
    public enum GoalScreenEntry: Sendable, Equatable, Hashable {
        /// タイムラインの左上の入口
        case goalLink
        /// 1日の目安の変更の知らせの「目標 ›」
        case dailyGuideChangeNotice
        /// 日のまとめの目標の行
        case daySummary
        /// 体重の画面の「目標 ›」
        case weightScreen
    }

    /// 目標の画面を開いたときの目標の状態。目標の値は持たない
    public enum GoalScreenStatus: Sendable, Equatable {
        case inProgress
        case achievedBeforeDeadline
        case deadlineReached
        case maintainingAfterDeadline

        /// 目標がなければ nil（目標の画面は開かない）
        public init?(_ status: GoalStatus) {
            switch status {
            case .noGoal: return nil
            case .inProgress: self = .inProgress
            case .achievedBeforeDeadline: self = .achievedBeforeDeadline
            case .deadlineReached: self = .deadlineReached
            case .maintainingAfterDeadline: self = .maintainingAfterDeadline
            }
        }
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
        case .textSent: "text_sent"
        case .presetTapped: "preset_tapped"
        case .resentAsConversation: "resent_as_conversation"
        case .replyRegenerateTapped: "reply_regenerate_tapped"
        case .replyFirstTextShown: "reply_first_text_shown"
        case .replyMealOpened: "reply_meal_opened"
        case .goalSetup(.opened): "goal_setup_opened"
        case .goalSetup(.closed): "goal_setup_closed"
        case .goalSetup(.decided): "goal_decided"
        case .goalSetup(.plansUnavailable): "goal_plans_unavailable"
        case .weeklyReviewOpened: "weekly_review_opened"
        case .goalScreenOpened: "goal_screen_opened"
        case .termsAgreementSheetShown: "terms_agreement_sheet_shown"
        case .termsAgreed: "terms_agreed"
        case .accountDeletionGuideOpened: "account_deletion_guide_opened"
        case .manageSubscriptionsOpened: "manage_subscriptions_opened"
        }
    }

    public var screenToken: String? {
        switch self {
        case .weightRecorded, .weightCorrected, .weightInputCancelled, .usageDataTurnedOff,
            .initialPullDuration, .mealRecorded, .cameraCancelled, .cameraPermissionNoticeShown,
            .mealDeleted, .mealTimeCorrected, .dishCorrected, .dishAdded, .dishDeleted,
            .unansweredNoticeLineTapped,
            .missedWeightReminderOpened,
            .notificationPermissionRequested, .notificationSettingsOpened, .textSent,
            .presetTapped, .resentAsConversation, .replyRegenerateTapped, .replyFirstTextShown,
            .replyMealOpened, .goalSetup, .weeklyReviewOpened, .goalScreenOpened,
            .termsAgreementSheetShown, .termsAgreed, .accountDeletionGuideOpened,
            .manageSubscriptionsOpened:
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
            .notificationSettingsOpened, .replyMealOpened, .termsAgreementSheetShown, .termsAgreed,
            .accountDeletionGuideOpened, .manageSubscriptionsOpened:
            [:]
        case .resentAsConversation(let deletedMealCount):
            ["deleted_meal_count": .count(deletedMealCount)]
        case .replyRegenerateTapped(let reason):
            ["reason": .token(reason.token)]
        case .replyFirstTextShown(let sinceSent, let watched):
            [
                "seconds_since_sent": .wholeSeconds(Self.wholeSeconds(sinceSent)),
                "watched": .flag(watched),
            ]
        case .missedWeightReminderOpened(let hadNotice):
            ["had_notice": .flag(hadNotice)]
        case .notificationPermissionRequested(let granted):
            ["granted": .flag(granted)]
        case .textSent(.none, let editedPreset, let length):
            ["edited_preset": .flag(editedPreset), "length": .count(length)]
        case .textSent(.some(let preset), let editedPreset, let length):
            [
                "preset": .token(preset.token),
                "edited_preset": .flag(editedPreset),
                "length": .count(length),
            ]
        case .presetTapped(let preset):
            ["preset": .token(preset.token)]
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
        case .goalSetup(.opened(let entry, let isRestart, let resumed)):
            [
                "entry": .token(entry.token), "is_restart": .flag(isRestart),
                "resumed": .flag(resumed),
            ]
        case .goalSetup(.closed(let page)):
            ["page": .token(page.token)]
        case .goalSetup(.decided(let choice, let recalculated)):
            ["choice": .token(choice.token), "recalculated": .flag(recalculated)]
        case .goalSetup(.plansUnavailable(let canBackCalculate)):
            canBackCalculate.map { ["can_back_calculate": .flag($0)] } ?? [:]
        case .weeklyReviewOpened(let entry, let weeksAgo):
            ["entry": .token(entry.token), "weeks_ago": .count(weeksAgo)]
        case .goalScreenOpened(let entry, let status):
            ["entry": .token(entry.token), "goal_status": .token(status.token)]
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

extension ClientUsageEvent.ReplyRegenerateReason {
    fileprivate var token: String {
        switch self {
        case .failed(.retriesExhausted): "retries_exhausted"
        case .failed(.badRequest): "bad_request"
        case .halted: "halted"
        }
    }
}

extension TextPreset {
    fileprivate var token: String {
        switch self {
        case .mealFeedbackSoFar: "meal_feedback_so_far"
        case .nextMealAdvice: "next_meal_advice"
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
        case .awaitingSubscription: "awaiting_subscription"
        case .failed: "failed"
        }
    }
}

extension ClientUsageEvent.WeeklyReviewEntry {
    fileprivate var token: String {
        switch self {
        case .weeklyReviewCard: "weekly_review_card"
        case .goalScreen: "goal_screen"
        case .daySummary: "day_summary"
        }
    }
}

extension GoalSetupObservation.Entry {
    fileprivate var token: String {
        switch self {
        case .noticeCard: "notice_card"
        case .unansweredNoticeLine: "unanswered_notice_line"
        case .daySummary: "day_summary"
        case .weightScreen: "weight_screen"
        case .chooseNextGoal: "choose_next_goal"
        case .setNextGoal: "set_next_goal"
        case .switchGoal: "switch_goal"
        }
    }
}

extension ClientUsageEvent.GoalScreenEntry {
    fileprivate var token: String {
        switch self {
        case .goalLink: "goal_link"
        case .dailyGuideChangeNotice: "daily_guide_change_notice"
        case .daySummary: "day_summary"
        case .weightScreen: "weight_screen"
        }
    }
}

extension ClientUsageEvent.GoalScreenStatus {
    fileprivate var token: String {
        switch self {
        case .inProgress: "in_progress"
        case .achievedBeforeDeadline: "achieved_before_deadline"
        case .deadlineReached: "deadline_reached"
        case .maintainingAfterDeadline: "maintaining_after_deadline"
        }
    }
}

extension GoalSetupObservation.Page {
    fileprivate var token: String {
        switch self {
        case .direction: "direction"
        case .deadline: "deadline"
        case .missingValues: "missing_values"
        case .proposals: "proposals"
        case .customTargetWeight: "custom_target_weight"
        case .maintenance: "maintenance"
        case .loseUnavailable: "lose_unavailable"
        case .stopped: "stopped"
        case .awaitingPreview: "awaiting_preview"
        }
    }
}

extension GoalSetupObservation.Choice {
    fileprivate var token: String {
        switch self {
        case .gentle: "gentle"
        case .standard: "standard"
        case .hard: "hard"
        case .custom: "custom"
        case .maintain: "maintain"
        }
    }
}
