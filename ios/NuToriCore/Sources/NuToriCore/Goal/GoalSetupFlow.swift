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

    public private(set) var isOpen = false
    public private(set) var direction: GoalSetupDirection?
    public private(set) var deadline: CalendarDay
    public let deadlineChoices: GoalDeadlineChoices
    /// 足りない値のページの欄と入れた値。逆算できないと分かるまでは nil
    public private(set) var missingValues: GoalSetupMissingValues?
    /// 目標案か維持の値。届くまでは nil
    public private(set) var proposals: GoalProposals?
    /// 目標案のページで選んでいる案
    public private(set) var selectedPace: GoalProposals.Pace?
    public private(set) var customTargetWeight: CustomTargetWeight?
    public private(set) var decision: Decision = .idle
    /// ページの中で電波が届かなかった要求。「ここまでの答えは残してあります。…」と「もう一度試す」を出す
    public private(set) var unreachableRequest: UnreachableRequest?
    /// 決めずに新しい案が返った。「新しい体重で計算し直しました。」を添える
    public private(set) var showsRecalculated = false

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

    /// 閉じたカードを「続ける」にするか
    public var hasProgress: Bool {
        direction != nil
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
            previewGeneration += 1
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
        await previewTask?.value
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
            proposalsUnreachable = false
            await fetchProposalsIfReady()
        }
    }

    public func selectPace(_ pace: GoalProposals.Pace) {
        guard case .weightChange(let weightChange)? = proposals?.plan,
            weightChange.offeredProposals.contains(where: { $0.pace == pace })
        else { return }
        selectedPace = pace
    }

    /// 「目標体重を自分で決める」。初期値は開くときに選ぶ案の目標体重
    public func openCustomTargetWeight() {
        guard case .weightChange(let weightChange)? = proposals?.plan,
            let range = weightChange.acceptedTargetWeightRange,
            let opening = proposals?.openingProposal
        else { return }
        if customTargetWeight == nil {
            customTargetWeight = CustomTargetWeight(
                kilograms: opening.targetWeightKilograms,
                direction: weightChange.direction,
                range: range,
                correctedReason: nil,
                assessment: CustomTargetWeightAssessment.Accepted(
                    dailyGuide: opening.dailyGuide, difficulty: opening.difficulty,
                    dailyGuideDifferenceKilocalories: opening.dailyGuideDifferenceKilocalories),
                isAssessing: false)
        }
        position = .custom
    }

    /// ステッパー・スライダー・キーボードで目標体重を動かす。受け付ける幅の外は端の値に直して数える。
    /// 止めて 0.3 秒たったら要求を出し、最後に出した要求の答えだけを使う
    public func setCustomTargetWeight(_ kilograms: Double) async {
        guard let custom = customTargetWeight else { return }
        let (clamped, reason) = custom.clamped(kilograms)
        if reason != nil {
            rejectedCustomTargetWeightCount += 1
        }
        customTargetWeight = custom.moved(to: clamped, correctedReason: reason)
        assessmentGeneration += 1
        let generation = assessmentGeneration
        let task = Task {
            do {
                try await wait(Self.customTargetWeightPause)
            } catch {
                // 次に動かした
                return
            }
            // 出した要求は、次に動かしても取り消さない。届いた順が入れ替わっても、最後に出した要求の答えだけを使う
            await Task { await self.sendAssessment(generation: generation) }.value
        }
        assessmentTask?.cancel()
        assessmentTask = task
        await task.value
    }

    /// 断るページの「維持にする」
    public func chooseMaintainInstead() async {
        await chooseDirection(.maintain)
    }

    /// 「この目標で始める」「維持で始める」。自分で決める目標体重の答えを待っていれば、届いてから決める
    public func decide() async {
        guard decision == .idle else { return }
        unreachableRequest = nil
        decision = .deciding
        if position == .custom {
            // 答えが受け付けない値の直しを連れてきたら、次の要求を待ち直す
            while customTargetWeight?.isAssessing == true, let task = assessmentTask {
                await task.value
                if task == assessmentTask { break }
            }
            guard unreachableRequest == nil, customTargetWeight?.isAssessing == false else {
                decision = .idle
                return
            }
        }
        await sendDecision()
    }

    // MARK: 中身

    private static let customTargetWeightPause = Duration.milliseconds(300)

    private let start: GoalSetupStart
    private let client: NuToriAPIClient
    private let records: any GoalSetupRecords
    private let health: GoalSetupHealthReader
    private let timeZone: @Sendable () -> TimeZone
    private let now: @Sendable () -> Date
    private let wait: @Sendable (Duration) async throws -> Void
    private let errorReporting: any ErrorReportingSession
    private let observe: @MainActor (GoalSetupObservation) -> Void

    private var position = Position.direction
    private var preview = PreviewState.notRequested
    /// 分かった逆算の答え。身体データを添えて下見を出し直すあいだも持つ
    private var canBackCalculate: Bool?
    private var proposalsUnreachable = false
    /// 足りない値の「次へ」で決めた身体データ
    private var submittedBody: GoalSetupBody?
    /// 使い始める前の日ごとの摂取エネルギー。初めての目標で読んだあと
    private var preUseEnergyIntakes: [String: Double]?
    private var hasAskedAuthorization = false
    private var hasRecordedCurrentWeight = false
    private var rejectedCustomTargetWeightCount = 0
    private var hasRecalculated = false
    private var reportedUnavailable = false
    /// 届いたか分からないまま送り直すときも同じ ID を使う
    private let decisionRequestId = UUID()
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    private var proposalsTask: Task<Void, Never>?
    private var proposalsGeneration = 0
    private var assessmentTask: Task<Void, Never>?
    private var assessmentGeneration = 0

    private enum Position: Equatable {
        case direction
        case deadline
        case missingValues
        /// 目標案・維持・断るページの場所
        case final
        case custom
    }

    private enum PreviewState: Equatable {
        case notRequested
        /// 立て直しの増量・維持は、下見の答えを使わない
        case notNeeded
        case inFlight
        case answered(GoalSetupPreview)
        case unreachable
    }

    private var isFirst: Bool {
        start.isFirst
    }

    /// 初めての目標は逆算できるかを、減量は案を出せるかを、下見に問う
    private var needsPreview: Bool {
        isFirst || direction == .lose
    }

    private var needsMissingValues: Bool {
        isFirst && canBackCalculate == false
    }

    private var isLoseRefused: Bool {
        guard direction == .lose else { return false }
        if case .answered(let answer) = preview, answer.canOfferLoseProposals == false {
            return true
        }
        if proposals?.offersNothing == true {
            return true
        }
        return false
    }

    /// 逆算できる人と立て直しは、減量を選んだ次の場所で断る
    private var isRefusedBeforeDeadline: Bool {
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
                canBackCalculate == nil && isFirst ? .beforeMissingValues : .beforeProposals)
        case .notRequested, .inFlight:
            if isFirst, canBackCalculate == nil {
                return .awaitingPreview
            }
        case .notNeeded, .answered:
            break
        }
        if proposalsUnreachable {
            return .stopped(.beforeProposals)
        }
        return direction == .maintain ? .maintenance : .proposals
    }

    private var observedPage: GoalSetupObservation.Page {
        switch page {
        case .direction: .direction
        case .deadline: .deadline
        case .awaitingPreview, .stopped: .stopped
        case .missingValues: .missingValues
        case .proposals: .proposals
        case .customTargetWeight: .customTargetWeight
        case .maintenance: .maintenance
        case .loseUnavailable: .loseUnavailable
        }
    }

    private var inputs: GoalSetupInputs {
        GoalSetupInputs(
            timeZone: timeZone(),
            preUseEnergyIntakes: isFirst ? preUseEnergyIntakes ?? [:] : nil,
            body: submittedBody)
    }

    private func clearProposals() {
        proposalsGeneration += 1
        proposals = nil
        proposalsUnreachable = false
        customTargetWeight = nil
        showsRecalculated = false
    }

    /// 下見を出す。初めての目標では、許可（1回だけ）、体重記録を送り切る、使い始める前の摂取エネルギーを読む、の順に済ませてから出す
    private func runPreview() async {
        previewGeneration += 1
        let generation = previewGeneration
        preview = .inFlight
        let task = Task { await self.sendPreview(generation: generation) }
        previewTask = task
        await task.value
    }

    private func sendPreview(generation: Int) async {
        guard let direction else { return }
        if isFirst {
            if !hasAskedAuthorization {
                hasAskedAuthorization = true
                // 許可しなかったことは指摘せずに先へ進む
                if (try? await health.hasUnrequestedAuthorization()) == true {
                    try? await health.requestAuthorization()
                }
            }
            if let weight = missingValues?.currentWeightKilograms, submittedBody != nil,
                !hasRecordedCurrentWeight
            {
                do {
                    try await records.recordWeight(kilograms: weight, at: now(), in: timeZone())
                    hasRecordedCurrentWeight = true
                } catch {
                    await errorReporting.report(error, as: .cacheSave)
                    finishPreview(.unreachable, generation: generation)
                    return
                }
            }
            guard await records.sendWeightRecordsForGoalSetup() else {
                finishPreview(.unreachable, generation: generation)
                return
            }
            if preUseEnergyIntakes == nil, case .first(let firstUseDay, _) = start {
                // 読めなければ、使い始める前の分を使わずに逆算を問う
                let intakes =
                    (try? await health.intakeEnergyBeforeFirstUse(firstUseDay: firstUseDay)) ?? [:]
                preUseEnergyIntakes = Dictionary(
                    uniqueKeysWithValues: intakes.map { ($0.key.yearMonthDay, $0.value) })
            }
        }
        let received: GoalSetupPreview
        do {
            let result = try await client.previewGoalSetup(direction: direction, inputs: inputs)
            guard case .answered(let answered) = await answer(of: result) else {
                finishPreview(.unreachable, generation: generation)
                return
            }
            received = answered
        } catch {
            await errorReporting.report(error, as: .goalSetupRequest)
            finishPreview(.unreachable, generation: generation)
            return
        }
        guard generation == previewGeneration else { return }
        if let canBackCalculate = received.canBackCalculate {
            self.canBackCalculate = canBackCalculate
        }
        if needsMissingValues, missingValues == nil {
            let body =
                (try? await health.bodyData())
                ?? HealthBodyData(heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:])
            guard generation == previewGeneration else { return }
            missingValues = GoalSetupMissingValues(
                health: body, asksCurrentWeight: !hasWeightRecords,
                today: CalendarDay(containing: now(), in: timeZone()))
        }
        finishPreview(.answered(received), generation: generation)
        if position == .final, needsMissingValues, submittedBody == nil {
            position = .missingValues
        }
        if position == .deadline, isRefusedBeforeDeadline {
            position = .final
        }
        await fetchProposalsIfReady()
    }

    private var hasWeightRecords: Bool {
        switch start {
        case .first(_, let hasWeightRecords): hasWeightRecords
        case .restart: true
        }
    }

    private func finishPreview(_ state: PreviewState, generation: Int) {
        guard generation == previewGeneration else { return }
        preview = state
        reportUnavailableIfNeeded()
    }

    private func fetchProposalsIfReady() async {
        guard position == .final || position == .custom, let direction, proposals == nil,
            !isLoseRefused, !(needsMissingValues && submittedBody == nil)
        else { return }
        switch preview {
        case .notNeeded, .answered: break
        case .notRequested, .inFlight, .unreachable: return
        }
        if let proposalsTask {
            await proposalsTask.value
            if proposals != nil || proposalsUnreachable { return }
        }
        proposalsGeneration += 1
        let generation = proposalsGeneration
        proposalsUnreachable = false
        let deadlineOn = direction == .maintain ? nil : deadline.yearMonthDay
        let task = Task {
            do {
                let result = try await self.client.proposeGoals(
                    direction: direction, deadlineOn: deadlineOn, inputs: self.inputs)
                guard generation == self.proposalsGeneration else { return }
                guard case .answered(let proposals) = await self.answer(of: result) else {
                    self.proposalsUnreachable = true
                    return
                }
                self.apply(proposals)
            } catch {
                await self.errorReporting.report(error, as: .goalSetupRequest)
                guard generation == self.proposalsGeneration else { return }
                self.proposalsUnreachable = true
            }
        }
        proposalsTask = task
        await task.value
        if proposalsTask == task {
            proposalsTask = nil
        }
    }

    /// 選んでいた案が出せれば残し、出せなければ開くときと同じ決まりで選び直す
    private func apply(_ proposals: GoalProposals) {
        self.proposals = proposals
        if case .weightChange(let weightChange) = proposals.plan {
            if !weightChange.offeredProposals.contains(where: { $0.pace == selectedPace }) {
                selectedPace = proposals.openingProposal?.pace
            }
            if let range = weightChange.acceptedTargetWeightRange {
                customTargetWeight = customTargetWeight?.rebased(on: range)
            }
        }
        reportUnavailableIfNeeded()
    }

    private func reportUnavailableIfNeeded() {
        guard isLoseRefused, !reportedUnavailable else { return }
        reportedUnavailable = true
        observe(.plansUnavailable(canBackCalculate: isFirst ? canBackCalculate : nil))
    }

    private func assessCustomTargetWeight() async {
        guard let custom = customTargetWeight else { return }
        customTargetWeight = custom.moved(
            to: custom.kilograms, correctedReason: custom.correctedReason)
        assessmentGeneration += 1
        let generation = assessmentGeneration
        let task = Task { await self.sendAssessment(generation: generation) }
        assessmentTask = task
        await task.value
    }

    private func sendAssessment(generation: Int) async {
        guard let custom = customTargetWeight else { return }
        do {
            let result = try await client.assessCustomTargetWeight(
                direction: custom.direction, deadlineOn: deadline.yearMonthDay,
                targetWeightKilograms: custom.kilograms, inputs: inputs)
            // 最後に出した要求の答えだけを使う
            guard generation == assessmentGeneration, let current = customTargetWeight else {
                return
            }
            guard case .answered(let assessment) = await answer(of: result) else {
                customTargetWeight = current.unassessed()
                unreachableRequest = .customTargetWeight
                return
            }
            switch assessment.outcome {
            case .accepted(let accepted):
                customTargetWeight = current.assessed(accepted)
            case .rejected(let reason, let nearest):
                guard let nearest else {
                    customTargetWeight = current.unassessed()
                    return
                }
                customTargetWeight = current.moved(to: nearest, correctedReason: reason)
                assessmentGeneration += 1
                let next = assessmentGeneration
                let task = Task { await self.sendAssessment(generation: next) }
                assessmentTask = task
            }
        } catch {
            await errorReporting.report(error, as: .goalSetupRequest)
            guard generation == assessmentGeneration, let current = customTargetWeight else {
                return
            }
            customTargetWeight = current.unassessed()
            unreachableRequest = .customTargetWeight
        }
    }

    private func sendDecision() async {
        guard let proposals, let (choice, shown) = decisionChoice(in: proposals) else {
            decision = .idle
            return
        }
        let request = GoalDecisionRequest(
            requestId: decisionRequestId,
            startedOn: proposals.startedOn,
            choice: choice,
            shownTargetWeightKilograms: shown.targetWeightKilograms,
            shownDailyGuide: shown.dailyGuide,
            rejectedCustomTargetWeightCount: rejectedCustomTargetWeightCount)
        let received: GoalDecision
        do {
            let result = try await client.decideGoal(request, inputs: inputs)
            guard case .answered(let answered) = await answer(of: result) else {
                decision = .idle
                unreachableRequest = .decision
                return
            }
            received = answered
        } catch {
            await errorReporting.report(error, as: .goalSetupRequest)
            decision = .idle
            unreachableRequest = .decision
            return
        }
        switch received {
        case .decided(let changes):
            do {
                try await records.applyGoalDecision(changes)
            } catch {
                // 同じ記録が同期でも届く
                await errorReporting.report(error, as: .cacheSave)
            }
            await records.respondToGoalSetupNotice()
            discardBodyValues()
            decision = .decided
            observe(.decided(choice: observedChoice(choice), recalculated: hasRecalculated))
        case .recalculated(let recalculated):
            hasRecalculated = true
            showsRecalculated = true
            apply(recalculated)
            decision = .idle
            if position == .custom {
                if let custom = customTargetWeight {
                    let (clamped, reason) = custom.clamped(custom.kilograms)
                    customTargetWeight = custom.moved(to: clamped, correctedReason: reason)
                }
                await assessCustomTargetWeight()
            }
        case .customTargetWeightRejected(_, let reason, let nearest):
            decision = .idle
            if let custom = customTargetWeight, let nearest {
                customTargetWeight = custom.moved(to: nearest, correctedReason: reason)
                await assessCustomTargetWeight()
            }
        }
    }

    private struct Shown {
        let targetWeightKilograms: Double
        let dailyGuide: DailyGuidePlan
    }

    private func decisionChoice(in proposals: GoalProposals) -> (GoalDecisionRequest.Choice, Shown)?
    {
        switch proposals.plan {
        case .maintenance(let maintenance):
            return (
                .maintain,
                Shown(
                    targetWeightKilograms: maintenance.targetWeightKilograms,
                    dailyGuide: maintenance.dailyGuide)
            )
        case .weightChange(let weightChange):
            if position == .custom {
                guard let custom = customTargetWeight else { return nil }
                return (
                    .custom(
                        direction: weightChange.direction, deadlineOn: weightChange.deadlineOn,
                        targetWeightKilograms: custom.kilograms),
                    Shown(
                        targetWeightKilograms: custom.kilograms,
                        dailyGuide: custom.assessment.dailyGuide)
                )
            }
            guard
                let selected = weightChange.offeredProposals.first(where: {
                    $0.pace == selectedPace
                })
            else { return nil }
            return (
                .proposal(
                    direction: weightChange.direction, deadlineOn: weightChange.deadlineOn,
                    pace: selected.pace),
                Shown(
                    targetWeightKilograms: selected.targetWeightKilograms,
                    dailyGuide: selected.dailyGuide)
            )
        }
    }

    private func observedChoice(_ choice: GoalDecisionRequest.Choice) -> GoalSetupObservation.Choice
    {
        switch choice {
        case .maintain: .maintain
        case .custom: .custom
        case .proposal(_, _, .gentle): .gentle
        case .proposal(_, _, .standard): .standard
        case .proposal(_, _, .hard): .hard
        }
    }

    private func discardBodyValues() {
        submittedBody = nil
        preUseEnergyIntakes = nil
        missingValues = nil
    }

    /// 断る応答（不具合のときだけ届く）とセッション切れ・歯止めは、答えが無いものとして扱う。断る応答は報告する
    private func answer<Answer: Sendable & Equatable>(of result: GoalSetupResult<Answer>) async
        -> GoalSetupResult<Answer>
    {
        switch result {
        case .answered, .sessionExpired, .rateLimited:
            break
        case .badRequest, .unprocessable:
            await errorReporting.report(.goalSetupRequest, cause: nil)
        }
        return result
    }
}
