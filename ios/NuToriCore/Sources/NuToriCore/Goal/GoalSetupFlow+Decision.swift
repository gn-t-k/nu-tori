import NuToriAPI

extension GoalSetupFlow {
    /// 「この目標で始める」「維持で始める」。自分で決める目標体重の答えを待っていれば、届いてから決める
    public func decide() async {
        guard decision == .idle else { return }
        let isCustomTargetWeightUnanswered = unreachableRequest == .customTargetWeight
        unreachableRequest = nil
        decision = .deciding
        if position == .custom {
            // 届かなかったときに見せている1日の目安は、今の目標体重のものではないので、問い直して届いてから決める
            if isCustomTargetWeightUnanswered {
                await assessCustomTargetWeight()
            }
            // 答えが受け付けない値の直しを連れてきたら、次の要求を待ち直す
            while customTargetWeight?.isAssessing == true, let task = assessmentRequest.task {
                await task.value
                if task == assessmentRequest.task { break }
            }
            guard unreachableRequest == nil, customTargetWeight?.isAssessing == false else {
                decision = .idle
                return
            }
        }
        await sendDecision()
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
                // 同じ記録が同期でも届くので、押せないまま残さずに決まったものとして閉じる
                await errorReporting.report(error, as: .cacheSave)
            }
            await records.respondToGoalSetupNotice()
            discardBodyValues()
            decision = .decided
            observe(.decided(choice: observedChoice(choice), recalculated: hasRecalculated))
            // 決まったら閉じる。カードは決めた目標を示す形になり、開き直すと新しく始める
            isOpen = false
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
}
