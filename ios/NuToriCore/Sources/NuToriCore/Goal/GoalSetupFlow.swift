public import Foundation
public import NuToriAPI
public import Observation

/// 目標の設定の流れ（知らせのカードをその場で広げ、向き →（ヘルスケアの許可）→ 期限 →（足りない値）→ 目標案 で目標を決める）の状態。
/// 計算はサーバーが行い、ここは、どのページを出すか、答えを残すこと、4つの要求をいつ出しどの答えを使うかを持つ。
/// 閉じても答えを残し、開き直すと同じページから続ける。身体データと使い始める前の摂取エネルギーは、ここにだけ持ち、目標が決まったら捨てる。
///
/// 操作のメソッドは、ページをその場で替えてから、始めた要求が終わるまで待って戻る（画面は待たずに呼び、テストは終わるのを待つ）
@MainActor
@Observable
public final class GoalSetupFlow {
    /// - Parameters:
    ///   - wait: 自分で決める目標体重を止めてから要求を出すまで待つ
    ///   - observe: 端末の PostHog に送る出来事の値を知らせる
    public init(
        start: GoalSetupStart,
        client: NuToriAPIClient,
        records: any GoalSetupRecords,
        health: GoalSetupHealthReader,
        timeZone: @escaping @Sendable () -> TimeZone,
        now: @escaping @Sendable () -> Date,
        wait: @escaping @Sendable (Duration) async throws -> Void,
        errorReporting: any ErrorReportingSession,
        observe: @escaping @MainActor (GoalSetupObservation) -> Void
    ) {
        self.start = start
        self.client = client
        self.records = records
        self.health = health
        self.timeZone = timeZone
        self.now = now
        self.wait = wait
        self.errorReporting = errorReporting
        self.observe = observe
        let choices = GoalDeadlineChoices(
            startDay: start.startDay(today: CalendarDay(containing: now(), in: timeZone())))
        deadlineChoices = choices
        deadline = choices.initialDay
    }

    // MARK: 見せるもの

    public internal(set) var isOpen = false
    public private(set) var direction: GoalSetupDirection?
    public internal(set) var deadline: CalendarDay
    /// 目標案の開始の日がずれたら、その日から数え直す
    public internal(set) var deadlineChoices: GoalDeadlineChoices
    /// 足りない値のページの欄と入れた値。逆算できないと分かるまでは nil
    public internal(set) var missingValues: GoalSetupMissingValues?
    /// 目標案か維持の値。届くまでと、届かなかったときは nil
    public var proposals: GoalProposals? {
        switch proposalsState {
        case .received(let proposals): proposals
        case .notReceived, .unreachable: nil
        }
    }
    /// 目標案のページで選んでいる案
    public internal(set) var selectedPace: GoalProposals.Pace?
    public internal(set) var customTargetWeight: CustomTargetWeight?
    public internal(set) var decision: Decision = .idle
    /// ページの中で電波が届かなかった要求。「インターネットにつながると、…」と「もう一度試す」を出す
    public internal(set) var unreachableRequest: UnreachableRequest?
    /// 決めずに新しい案が返った。「新しい体重で計算し直しました。」を添える
    public internal(set) var showsRecalculated = false

    /// 足りない値の「次へ」で決めた身体データ。目標案の上の1行に見せ、要求に添える。逆算できる人と、決めたあとは nil
    public internal(set) var submittedBody: GoalSetupBody?

    /// 目標案の上の1行に出す、計算に使った値。目標案が届く前は nil。
    /// 身体データを添えずに式の目標案が返ったとき（届かないはずの組み合わせ）も、どの値を使ったか言えないので nil
    public var usedValues: GoalSetupUsedValues? {
        guard let proposals else { return nil }
        switch proposals.expenditureSource {
        case .backCalculated:
            return .backCalculated(expenditureKilocalories: proposals.expenditureKilocalories)
        case .formula:
            return submittedBody.map {
                .formula($0, weightKilograms: proposals.startingWeightTrendKilograms)
            }
        case .current:
            return .current(expenditureKilocalories: proposals.expenditureKilocalories)
        }
    }

    /// 今日の体重の記録が無いときの、目標案に使った最後の体重記録の日（「体重は 9月21日までの記録を使っています。」）。
    /// 今日の記録があるときと、目標案が届く前は nil
    public var pastWeightRecordDay: CalendarDay? {
        guard let proposals, let day = CalendarDay(yearMonthDay: proposals.lastWeightRecordedOn),
            day < CalendarDay(containing: now(), in: timeZone())
        else { return nil }
        return day
    }

    public var page: GoalSetupPage {
        switch position {
        case .direction: .direction
        case .deadline: .deadline
        case .missingValues: .missingValues
        case .custom: .customTargetWeight
        case .final: finalPage
        }
    }

    /// 残りの手順の点。数はその人に要るページの数で、逆算できないと分かると1つ増える
    public var progress: Progress {
        let steps = steps
        let current = position == .custom ? .final : position
        return Progress(count: steps.count, index: steps.firstIndex(of: current) ?? 0)
    }

    /// 閉じたカードを「続ける」にするか。決めたあとは、続けるものが無い
    public var hasProgress: Bool {
        direction != nil && decision != .decided
    }

    public var isRestart: Bool {
        !start.isFirst
    }

    public struct Progress: Sendable, Equatable {
        public let count: Int
        /// 0 から
        public let index: Int

        public init(count: Int, index: Int) {
            self.count = count
            self.index = index
        }
    }

    public enum Decision: Sendable, Equatable {
        case idle
        /// 「この目標で始める」「維持で始める」を押した。自分で決める目標体重の答えを待つあいだも含む
        case deciding
        case decided
    }

    public enum UnreachableRequest: Sendable, Equatable {
        case customTargetWeight
        case decision
    }

    // MARK: 操作

    public func open(from entry: GoalSetupObservation.Entry) {
        guard !isOpen else { return }
        observe(.opened(entry: entry, isRestart: isRestart, resumed: hasProgress))
        isOpen = true
    }

    public func close() {
        guard isOpen else { return }
        isOpen = false
        observe(.closed(page: observedPage))
    }

    /// 向きを選ぶ。初めての目標でまだ求めていない種類があれば、許可を求めてから下見を出す。期限と足りない値の答えは残す
    public func chooseDirection(_ direction: GoalSetupDirection) async {
        self.direction = direction
        clearProposals()
        reportedUnavailable = false
        position =
            switch direction {
            case .lose, .gain: .deadline
            case .maintain: needsMissingValues ? .missingValues : .final
            }
        guard needsPreview else {
            previewRequest.invalidate()
            preview = .notNeeded
            await fetchProposalsIfReady()
            return
        }
        await runPreview()
    }

    public func chooseDeadline(_ day: CalendarDay) {
        guard deadlineChoices.contains(day), day != deadline else { return }
        deadline = day
        clearProposals()
    }

    /// 期限のページの「次へ」
    public func proceedFromDeadline() async {
        guard position == .deadline else { return }
        position = needsMissingValues ? .missingValues : .final
        await previewRequest.task?.value
        await fetchProposalsIfReady()
    }

    public func enterMissingValues(_ entry: GoalSetupMissingValues.Entry) {
        missingValues = missingValues?.entering(entry)
    }

    /// 足りない値のページの「次へ」。今の体重を入れていれば今日の体重記録にして送り切り、身体データを添えて下見を出し直す
    public func proceedFromMissingValues() async {
        guard position == .missingValues, let missingValues, let body = missingValues.body,
            missingValues.isComplete
        else { return }
        submittedBody = body
        clearProposals()
        position = .final
        await runPreview()
    }

    /// 「戻る」。答えは残す
    public func goBack() {
        unreachableRequest = nil
        switch position {
        case .direction:
            return
        case .custom:
            position = .final
        case .deadline, .missingValues, .final:
            let steps = steps
            guard let index = steps.firstIndex(of: position), index > 0 else {
                position = .direction
                return
            }
            position = steps[index - 1]
        }
    }

    /// 目標案の上の1行の「変える」。答えを残して足りない値のページへ戻る
    public func reviseMissingValues() {
        guard needsMissingValues, position == .final || position == .custom else { return }
        unreachableRequest = nil
        position = .missingValues
    }

    /// 止まった場所とページの中の「もう一度試す」
    public func retry() async {
        switch unreachableRequest {
        case .customTargetWeight:
            unreachableRequest = nil
            await assessCustomTargetWeight()
            return
        case .decision:
            unreachableRequest = nil
            await decide()
            return
        case nil:
            break
        }
        guard case .stopped = page else { return }
        if case .unreachable = preview {
            await runPreview()
        } else {
            proposalsState = .notReceived
            await fetchProposalsIfReady()
        }
    }

    /// 断るページの「維持にする」
    public func chooseMaintainInstead() async {
        await chooseDirection(.maintain)
    }

    // MARK: 中身

    let start: GoalSetupStart
    let client: NuToriAPIClient
    let records: any GoalSetupRecords
    let health: GoalSetupHealthReader
    let timeZone: @Sendable () -> TimeZone
    let now: @Sendable () -> Date
    let wait: @Sendable (Duration) async throws -> Void
    let errorReporting: any ErrorReportingSession
    let observe: @MainActor (GoalSetupObservation) -> Void

    var position = Position.direction
    var preview = PreviewState.notRequested
    /// 分かった逆算の答え。身体データを添えて下見を出し直すあいだも持つ
    var backCalculation = BackCalculation.unknown
    var proposalsState = ProposalsState.notReceived
    /// 使い始める前の日ごとの摂取エネルギー。初めての目標で読んだあと
    var preUseEnergyIntakes: [CalendarDay: Double]?
    var hasAskedAuthorization = false
    var hasRecordedCurrentWeight = false
    var rejectedCustomTargetWeightCount = 0
    var hasRecalculated = false
    private var reportedUnavailable = false
    /// 届いたか分からないまま送り直すときも同じ ID を使う
    let decisionRequestId = UUID()
    var previewRequest = LatestRequest()
    var proposalsRequest = LatestRequest()
    var assessmentRequest = LatestRequest()

    enum Position: Equatable {
        case direction
        case deadline
        case missingValues
        /// 目標案・維持・断るページの場所
        case final
        case custom
    }

    enum ProposalsState: Equatable {
        case notReceived
        case received(GoalProposals)
        /// 電波が届かなかった
        case unreachable
    }

    /// 初めての目標で、推定消費カロリーを記録から逆算できるか。立て直しは問わないので、いつも unknown
    enum BackCalculation: Equatable {
        case unknown
        case possible
        case impossible

        /// 足りない値を尋ねるか
        var needsBodyData: Bool {
            self == .impossible
        }

        /// 観測に載せる値。分かっていなければ nil
        var observed: Bool? {
            switch self {
            case .unknown: nil
            case .possible: true
            case .impossible: false
            }
        }
    }

    enum PreviewState: Equatable {
        case notRequested
        /// 立て直しの増量・維持は、下見の答えを使わない
        case notNeeded
        case inFlight
        case answered(GoalSetupPreview)
        case unreachable
    }

    var isFirst: Bool {
        start.isFirst
    }

    /// 初めての目標は逆算できるかを、減量は案を出せるかを、下見に問う
    private var needsPreview: Bool {
        isFirst || direction == .lose
    }

    var needsMissingValues: Bool {
        isFirst && backCalculation.needsBodyData
    }

    var isLoseRefused: Bool {
        guard direction == .lose else { return false }
        if case .answered(let answer) = preview, answer.canOfferLoseProposals == false {
            return true
        }
        if case .received(let proposals) = proposalsState, proposals.offersNothing {
            return true
        }
        return false
    }

    /// 逆算できる人と立て直しは、減量を選んだ次の場所で断る
    var isRefusedBeforeDeadline: Bool {
        isLoseRefused && !needsMissingValues
    }

    private var steps: [Position] {
        var steps: [Position] = [.direction]
        if direction != .maintain, !isRefusedBeforeDeadline {
            steps.append(.deadline)
        }
        if needsMissingValues {
            steps.append(.missingValues)
        }
        steps.append(.final)
        return steps
    }

    private var finalPage: GoalSetupPage {
        if isLoseRefused {
            return .loseUnavailable
        }
        switch preview {
        case .unreachable:
            return .stopped(
                backCalculation == .unknown && isFirst ? .beforeMissingValues : .beforeProposals)
        case .notRequested, .inFlight:
            if isFirst, backCalculation == .unknown {
                return .awaitingPreview
            }
        case .notNeeded, .answered:
            break
        }
        if proposalsState == .unreachable {
            return .stopped(.beforeProposals)
        }
        return direction == .maintain ? .maintenance : .proposals
    }

    private var observedPage: GoalSetupObservation.Page {
        switch page {
        case .direction: .direction
        case .deadline: .deadline
        case .awaitingPreview: .awaitingPreview
        case .stopped: .stopped
        case .missingValues: .missingValues
        case .proposals: .proposals
        case .customTargetWeight: .customTargetWeight
        case .maintenance: .maintenance
        case .loseUnavailable: .loseUnavailable
        }
    }

    var inputs: GoalSetupInputs {
        GoalSetupInputs(
            timeZone: timeZone(),
            preUseEnergyIntakes: isFirst
                ? Dictionary(
                    uniqueKeysWithValues: (preUseEnergyIntakes ?? [:]).map {
                        ($0.key.yearMonthDay, $0.value)
                    }) : nil,
            body: submittedBody)
    }

    func reportUnavailableIfNeeded() {
        guard isLoseRefused, !reportedUnavailable else { return }
        reportedUnavailable = true
        observe(.plansUnavailable(canBackCalculate: backCalculation.observed))
    }

    /// 断る応答（不具合のときだけ届く）とセッション切れ・歯止めは、答えが無いものとして nil にする。断る応答は報告する
    func answered<Answer: Sendable & Equatable>(_ result: GoalSetupResult<Answer>) async
        -> Answer?
    {
        switch result {
        case .answered(let answer):
            return answer
        case .sessionExpired, .rateLimited:
            return nil
        case .badRequest, .unprocessable:
            await errorReporting.report(.goalSetupRequest, cause: nil)
            return nil
        }
    }
}
