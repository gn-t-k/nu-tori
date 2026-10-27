public import Foundation

/// タイムラインの画面の移り方。開いているもの（シート・カメラ・写真を選ぶ画面）と、潜った画面の並びを、出来事を受けて替える。
/// 開いているものは `presentation` の1つだけなので、移るときは置き換えるか nil にすれば、ほかは閉じる
public struct TimelineNavigation: Equatable, Sendable {
    /// 潜った画面の並び。タイムラインに近い順
    public private(set) var path: [Route] = []
    /// 開いている、または開く用意をしているもの。同時には1つだけ
    public private(set) var presentation: Presentation?

    public init() {}

    /// 出来事を受けて移り、画面に頼むことを返す。目標の画面と課金画面を開けるかは `snapshot` で決める
    public mutating func receive(_ event: Event, on snapshot: TimelineSnapshot) -> [Effect] {
        switch event {
        case .dayRingTapped(let day):
            presentation = .daySummary(day)
        case .accountTapped:
            presentation = .account
        case .paywallRequested(let entry):
            hideCameraNotice()
            if let request = snapshot.paywallRequest(from: entry) {
                presentation = .paywall(request)
            }
        case .goalSetupRequested(let entry):
            presentation = nil
            path = []
            return [.openGoalSetup(entry)]
        case .goalScreenRequested(let entry):
            hideCameraNotice()
            guard snapshot.goalOverview != nil else { return [] }
            push(.goalScreen(entry))
        case .weeklyReviewRequested(let day, let entry):
            push(.weeklyReview(monday: day.startOfWeek, entry: entry))
        case .weightScreenRequested(let day):
            push(.weightScreen(day))
        case .mealRequested(let mealId):
            push(.meal(mealId))
        case .returnedToTimeline:
            path = []
        case .pathChanged(let changed):
            path = changed
        case .daySummaryClosed:
            if case .daySummary = presentation {
                presentation = nil
            }
        case .dismissed(let dismissed):
            guard presentation == dismissed else { return [] }
            presentation = nil
            return dismissed.returnsToTimeline ? [.capture(.screen(.timeline))] : []
        case .weightEntryTapped:
            hideCameraNotice()
            guard !presentation.isWeightEntry else { return [] }
            presentation = .weightEntry(.preparing)
            return [.prepareWeightEntry]
        case .weightEntryPrepared:
            guard presentation == .weightEntry(.preparing) else { return [] }
            presentation = .weightEntry(.showing)
        case .weightRecordedInEntry:
            guard presentation == .weightEntry(.showing) else { return [] }
            recordedInWeightEntry = true
            presentation = nil
            return [.capture(.screen(.timeline))]
        case .weightEntryDisappeared:
            // 通知の許可は、記録したシートが閉じてから求める。シートの上に重ねない
            guard recordedInWeightEntry else { return [] }
            recordedInWeightEntry = false
            return [.requestNotificationPermission]
        case .cameraTapped:
            hideCameraNotice()
            guard !presentation.isCamera else { return [] }
            presentation = .camera(.preparing)
            return [.prepareCamera]
        case .cameraReady:
            guard presentation == .camera(.preparing) else { return [] }
            presentation = .camera(.showing)
        case .cameraNotPermitted:
            guard presentation == .camera(.preparing) else { return [] }
            presentation = .cameraPermissionNotice
            return [.capture(.cameraPermissionNoticeShown)]
        case .cameraUnavailable:
            guard presentation == .camera(.preparing) else { return [] }
            presentation = nil
        case .photoTaken:
            guard presentation == .camera(.showing) else { return [] }
            presentation = nil
            return [.capture(.screen(.timeline))]
        case .cameraCancelled:
            guard presentation == .camera(.showing) else { return [] }
            presentation = nil
            return [.capture(.cameraCancelled), .capture(.screen(.timeline))]
        case .photoPickerTapped:
            presentation = .photoPicker
        case .composerTapped, .timelineScrolled, .timelineLeft:
            hideCameraNotice()
        }
        return []
    }

    /// 潜る行き先。行き先の画面は、そのときの表示の値で中身を組む
    public enum Route: Hashable, Sendable {
        case weightScreen(CalendarDay)
        /// 体重の画面の「すべての記録」
        case weightHistory
        case meal(UUID)
        /// 食事の画面から潜る料理の画面
        case dish(mealId: UUID, dishId: UUID)
        case goalScreen(ClientUsageEvent.GoalScreenEntry)
        /// ‹ › で送った週は画面の中で持つ
        case weeklyReview(monday: CalendarDay, entry: ClientUsageEvent.WeeklyReviewEntry)
    }

    public enum Presentation: Equatable, Sendable {
        case daySummary(CalendarDay)
        case account
        case paywall(PaywallRequest)
        case weightEntry(Phase)
        case camera(Phase)
        case photoPicker
        /// カメラを許可していない人に、入力欄の上に出す知らせ。ほかを押すか、タイムラインを動かすと消える
        case cameraPermissionNotice

        /// 閉じたら、タイムラインに戻ったとして送るもの
        fileprivate var returnsToTimeline: Bool {
            switch self {
            case .weightEntry(.showing), .camera(.showing): true
            case .daySummary, .account, .paywall, .weightEntry(.preparing), .camera(.preparing),
                .photoPicker, .cameraPermissionNotice:
                false
            }
        }
    }

    public enum Phase: Equatable, Sendable {
        /// 体重のシートはヘルスケアを読み、カメラは許可を確かめている（初めてなら、iOS の許可の画面を出している）
        case preparing
        case showing
    }

    public enum Event: Equatable, Sendable {
        case dayRingTapped(CalendarDay)
        case accountTapped
        case paywallRequested(ClientUsageEvent.PaywallEntry)
        /// 目標の設定のカードを、タイムラインで広げる
        case goalSetupRequested(GoalSetupObservation.Entry)
        case goalScreenRequested(ClientUsageEvent.GoalScreenEntry)
        /// その日を含む週の振り返り
        case weeklyReviewRequested(weekOf: CalendarDay, ClientUsageEvent.WeeklyReviewEntry)
        case weightScreenRequested(CalendarDay)
        case mealRequested(UUID)
        /// 潜った画面から、タイムラインまで戻る（食事を消した、週の振り返りで日を選んだ）
        case returnedToTimeline
        /// 戻るボタン・左端からの送り・`NavigationLink` で、並びが変わった
        case pathChanged([Route])
        /// 日のまとめでタイムラインの日を選んだ、タイムラインを動かして日のまとめを閉じる指示が出た
        case daySummaryClosed
        /// 下へ送る・閉じるボタンで、開いていたものが閉じた
        case dismissed(Presentation)
        case weightEntryTapped
        case weightEntryPrepared
        case weightRecordedInEntry
        /// 体重のシートが消え終えた
        case weightEntryDisappeared
        case cameraTapped
        case cameraReady
        case cameraNotPermitted
        /// シミュレーターのように、カメラが無い
        case cameraUnavailable
        /// 「写真を使用」を押した
        case photoTaken
        case cameraCancelled
        case photoPickerTapped
        /// 入力欄のほかの操作（定型文・送る・選んだ写真を決めてある UI テスト）を押した
        case composerTapped
        case timelineScrolled
        /// 体重や食事の画面に潜った
        case timelineLeft
    }

    /// 移ったあとに画面に頼むこと
    public enum Effect: Equatable, Sendable {
        /// 終えたら `weightEntryPrepared`
        case prepareWeightEntry
        /// 終えたら `cameraReady`・`cameraNotPermitted`・`cameraUnavailable`
        case prepareCamera
        /// 目標の設定のカードをタイムラインで広げ、カードまで送る
        case openGoalSetup(GoalSetupObservation.Entry)
        case requestNotificationPermission
        case capture(ClientUsageEvent)
    }

    /// 体重のシートで記録したか。シートが消えたら通知の許可を求める合図
    private var recordedInWeightEntry = false

    /// 開いているものを閉じてから、今の画面の上に押して進む
    private mutating func push(_ route: Route) {
        presentation = nil
        path.append(route)
    }

    /// カメラの許可の知らせだけを消す。ほかに開いているものは閉じない
    private mutating func hideCameraNotice() {
        if presentation == .cameraPermissionNotice {
            presentation = nil
        }
    }
}

extension TimelineNavigation.Presentation? {
    fileprivate var isWeightEntry: Bool {
        if case .weightEntry = self { true } else { false }
    }

    fileprivate var isCamera: Bool {
        if case .camera = self { true } else { false }
    }
}
