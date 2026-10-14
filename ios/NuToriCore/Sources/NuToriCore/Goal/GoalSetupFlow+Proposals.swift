public import NuToriAPI

extension GoalSetupFlow {
    // MARK: 操作

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
        // 待っている前の要求は出さない
        assessmentRequest.task?.cancel()
        let pause = Duration.milliseconds(300)
        let task = assessmentRequest.start { generation in
            do {
                try await self.wait(pause)
            } catch {
                // 次に動かした
                return
            }
            // 出した要求は、次に動かしても取り消さない。届いた順が入れ替わっても、最後に出した要求の答えだけを使う
            await Task { await self.sendAssessment(generation: generation) }.value
        }
        await task.value
    }

    // MARK: 中身

    func clearProposals() {
        proposalsRequest.invalidate()
        proposalsState = .notReceived
        customTargetWeight = nil
        showsRecalculated = false
    }

    func fetchProposalsIfReady() async {
        guard position == .final || position == .custom, let direction,
            proposalsState == .notReceived, !isLoseRefused,
            !(needsMissingValues && submittedBody == nil)
        else { return }
        switch preview {
        case .notNeeded, .answered: break
        case .notRequested, .inFlight, .unreachable: return
        }
        if let running = proposalsRequest.task {
            await running.value
            if proposalsState != .notReceived { return }
        }
        let plan: GoalProposalsPlan =
            switch direction {
            case .maintain: .maintain
            case .lose: .weightChange(direction: .lose, deadlineOn: deadline.yearMonthDay)
            case .gain: .weightChange(direction: .gain, deadlineOn: deadline.yearMonthDay)
            }
        let task = proposalsRequest.start { generation in
            do {
                let result = try await self.client.proposeGoals(plan, inputs: self.inputs)
                guard self.proposalsRequest.isLatest(generation) else { return }
                guard let proposals = await self.answered(result) else {
                    self.proposalsState = .unreachable
                    return
                }
                self.apply(proposals)
            } catch {
                await self.errorReporting.report(error, as: .goalSetupRequest)
                guard self.proposalsRequest.isLatest(generation) else { return }
                self.proposalsState = .unreachable
            }
        }
        await task.value
        proposalsRequest.finish(task)
    }

    /// 選んでいた案が出せれば残し、出せなければ開くときと同じ決まりで選び直す
    func apply(_ proposals: GoalProposals) {
        proposalsState = .received(proposals)
        // 日をまたいで開始の日がずれると、サーバーは期限を受け付ける幅に寄せた案を返すので、返った開始の日と期限を使い直す
        if let startDay = CalendarDay(yearMonthDay: proposals.startedOn),
            startDay != deadlineChoices.startDay
        {
            deadlineChoices = GoalDeadlineChoices(startDay: startDay)
        }
        if case .weightChange(let weightChange) = proposals.plan {
            if let deadlineDay = CalendarDay(yearMonthDay: weightChange.deadlineOn) {
                deadline = deadlineDay
            }
            if !weightChange.offeredProposals.contains(where: { $0.pace == selectedPace }) {
                selectedPace = proposals.openingProposal?.pace
            }
            if let range = weightChange.acceptedTargetWeightRange {
                customTargetWeight = customTargetWeight?.rebased(on: range)
            }
        }
        reportUnavailableIfNeeded()
    }

    func assessCustomTargetWeight() async {
        guard let custom = customTargetWeight else { return }
        customTargetWeight = custom.moved(
            to: custom.kilograms, correctedReason: custom.correctedReason)
        await assessmentRequest.start { await self.sendAssessment(generation: $0) }.value
    }

    private func sendAssessment(generation: Int) async {
        guard let custom = customTargetWeight else { return }
        do {
            let result = try await client.assessCustomTargetWeight(
                direction: custom.direction, deadlineOn: deadline.yearMonthDay,
                targetWeightKilograms: custom.kilograms, inputs: inputs)
            // 最後に出した要求の答えだけを使う
            guard assessmentRequest.isLatest(generation), let current = customTargetWeight else {
                return
            }
            guard let assessment = await self.answered(result) else {
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
                _ = assessmentRequest.start { await self.sendAssessment(generation: $0) }
            }
        } catch {
            await errorReporting.report(error, as: .goalSetupRequest)
            guard assessmentRequest.isLatest(generation), let current = customTargetWeight else {
                return
            }
            customTargetWeight = current.unassessed()
            unreachableRequest = .customTargetWeight
        }
    }
}
