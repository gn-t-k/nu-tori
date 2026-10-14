import NuToriAPI

extension GoalSetupFlow {
    /// 下見を出す。初めての目標では、許可（1回だけ）、体重記録を送り切る、使い始める前の摂取エネルギーを読む、の順に済ませてから出す
    func runPreview() async {
        preview = .inFlight
        await previewRequest.start { await self.sendPreview(generation: $0) }.value
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
                preUseEnergyIntakes = intakes
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
        guard previewRequest.isLatest(generation) else { return }
        if let canBackCalculate = received.canBackCalculate {
            backCalculation = canBackCalculate ? .possible : .impossible
        }
        if needsMissingValues, missingValues == nil {
            let body =
                (try? await health.bodyData())
                ?? HealthBodyData(heightCentimeters: nil, age: nil, sex: nil, dailySteps: [:])
            guard previewRequest.isLatest(generation) else { return }
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
        guard previewRequest.isLatest(generation) else { return }
        preview = state
        reportUnavailableIfNeeded()
    }
}
