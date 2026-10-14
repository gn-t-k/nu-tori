import Foundation
import OpenAPIRuntime

/// 目標の設定の、同期の外でその場で答える4つの要求。つながらないときは投げる
extension NuToriAPIClient {
    /// 目標の下見。初めての目標では、先に体重記録を同期で送り切ってから呼ぶ
    public func previewGoalSetup(direction: GoalSetupDirection, inputs: GoalSetupInputs)
        async throws -> GoalSetupResult<GoalSetupPreview>
    {
        typealias Payload = Operations.PreviewGoalSetup.Input.Body.JsonPayload
        let output = try await client.previewGoalSetup(
            body: .json(
                Payload(
                    timeZone: inputs.timeZone.identifier,
                    preUseEnergyIntakes: inputs.wireIntakes(
                        Payload.PreUseEnergyIntakesPayloadPayload.init),
                    bodyData: inputs.body.map(Components.Schemas.GoalSetupBodyData.init),
                    direction: Payload.DirectionPayload(direction)
                )))
        switch output {
        case .ok(let ok):
            let body = try ok.body.json
            return .answered(
                GoalSetupPreview(
                    canBackCalculate: body.canBackCalculate,
                    canOfferLoseProposals: body.canOfferLoseProposals))
        case .badRequest(let response): return .badRequest(code: try response.body.json.code)
        case .unprocessableContent(let response):
            return .unprocessable(code: try response.body.json.code)
        case .unauthorized: return .sessionExpired
        case .tooManyRequests: return .rateLimited
        case .undocumented(let statusCode, _): throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 目標案
    public func proposeGoals(_ plan: GoalProposalsPlan, inputs: GoalSetupInputs) async throws
        -> GoalSetupResult<GoalProposals>
    {
        typealias Payload = Operations.ProposeGoals.Input.Body.JsonPayload
        let output = try await client.proposeGoals(
            body: .json(
                Payload(
                    timeZone: inputs.timeZone.identifier,
                    preUseEnergyIntakes: inputs.wireIntakes(
                        Payload.PreUseEnergyIntakesPayloadPayload.init),
                    bodyData: inputs.body.map(Components.Schemas.GoalSetupBodyData.init),
                    plan: Components.Schemas.GoalProposalsPlan(plan)
                )))
        switch output {
        case .ok(let ok): return .answered(GoalProposals(try ok.body.json))
        case .badRequest(let response): return .badRequest(code: try response.body.json.code)
        case .unprocessableContent(let response):
            return .unprocessable(code: try response.body.json.code)
        case .unauthorized: return .sessionExpired
        case .tooManyRequests: return .rateLimited
        case .undocumented(let statusCode, _): throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 自分で決める目標体重
    public func assessCustomTargetWeight(
        direction: GoalProposals.Direction,
        deadlineOn: String,
        targetWeightKilograms: Double,
        inputs: GoalSetupInputs
    ) async throws -> GoalSetupResult<CustomTargetWeightAssessment> {
        typealias Payload = Operations.AssessCustomTargetWeight.Input.Body.JsonPayload
        let output = try await client.assessCustomTargetWeight(
            body: .json(
                Payload(
                    timeZone: inputs.timeZone.identifier,
                    preUseEnergyIntakes: inputs.wireIntakes(
                        Payload.PreUseEnergyIntakesPayloadPayload.init),
                    bodyData: inputs.body.map(Components.Schemas.GoalSetupBodyData.init),
                    direction: direction.wire(lose: .lose, gain: .gain),
                    deadlineOn: deadlineOn,
                    targetWeightKg: targetWeightKilograms
                )))
        switch output {
        case .ok(let ok): return .answered(CustomTargetWeightAssessment(try ok.body.json))
        case .badRequest(let response): return .badRequest(code: try response.body.json.code)
        case .unprocessableContent(let response):
            return .unprocessable(code: try response.body.json.code)
        case .unauthorized: return .sessionExpired
        case .tooManyRequests: return .rateLimited
        case .undocumented(let statusCode, _): throw UndocumentedStatusError(statusCode: statusCode)
        }
    }

    /// 目標を決める。同じ要求の ID の再送は、サーバーが書かずに初めての答えと同じ形で返す
    public func decideGoal(_ request: GoalDecisionRequest, inputs: GoalSetupInputs) async throws
        -> GoalSetupResult<GoalDecision>
    {
        typealias Payload = Operations.DecideGoal.Input.Body.JsonPayload
        let output = try await client.decideGoal(
            body: .json(
                Payload(
                    timeZone: inputs.timeZone.identifier,
                    preUseEnergyIntakes: inputs.wireIntakes(
                        Payload.PreUseEnergyIntakesPayloadPayload.init),
                    bodyData: inputs.body.map(Components.Schemas.GoalSetupBodyData.init),
                    requestId: request.requestId.canonicalString,
                    startedOn: request.startedOn,
                    choice: Components.Schemas.GoalChoice(request.choice),
                    shown: Components.Schemas.GoalShownValues(
                        targetWeightKg: request.shownTargetWeightKilograms,
                        dailyGuide: Components.Schemas.DailyGuidePlan(request.shownDailyGuide)),
                    rejectedCustomTargetWeightCount: request.rejectedCustomTargetWeightCount
                )))
        switch output {
        case .ok(let ok): return .answered(GoalDecision(try ok.body.json))
        case .badRequest(let response): return .badRequest(code: try response.body.json.code)
        case .unprocessableContent(let response):
            return .unprocessable(code: try response.body.json.code)
        case .unauthorized: return .sessionExpired
        case .tooManyRequests: return .rateLimited
        case .undocumented(let statusCode, _): throw UndocumentedStatusError(statusCode: statusCode)
        }
    }
}

extension GoalSetupInputs {
    /// 日の順に並べる。要求ごとに生成した型が違うので、作り方を受け取る
    fileprivate func wireIntakes<Intake>(_ make: (String, Double) -> Intake) -> [Intake]? {
        preUseEnergyIntakes.map { intakes in
            intakes.sorted { $0.key < $1.key }.map { make($0.key, $0.value) }
        }
    }
}

extension Operations.PreviewGoalSetup.Input.Body.JsonPayload.DirectionPayload {
    fileprivate init(_ direction: GoalSetupDirection) {
        switch direction {
        case .lose: self = .lose
        case .gain: self = .gain
        case .maintain: self = .maintain
        }
    }
}

extension Components.Schemas.GoalProposalsPlan {
    fileprivate init(_ plan: GoalProposalsPlan) {
        switch plan {
        case .maintain:
            self = .maintain(.init(direction: .maintain))
        case .weightChange(.lose, let deadlineOn):
            self = .lose(.init(direction: .lose, deadlineOn: deadlineOn))
        case .weightChange(.gain, let deadlineOn):
            self = .gain(.init(direction: .gain, deadlineOn: deadlineOn))
        }
    }
}

extension Components.Schemas.GoalSetupBodyData {
    fileprivate init(_ body: GoalSetupBody) {
        let activity: Components.Schemas.GoalSetupActivity =
            switch body.activity {
            case .steps(let dailySteps):
                .steps(
                    .init(
                        _type: .steps,
                        dailySteps: dailySteps.sorted { $0.key < $1.key }.map {
                            .init(calendarDay: $0.key, steps: $0.value)
                        }))
            case .level(let level):
                .level(.init(_type: .level, level: .init(level)))
            }
        let sex: Components.Schemas.GoalSetupBodyData.SexPayload =
            switch body.sex {
            case .male: .male
            case .female: .female
            }
        self.init(
            sex: sex,
            heightCentimeters: body.heightCentimeters,
            ageYears: body.ageYears,
            activity: activity)
    }
}

extension Components.Schemas.GoalSetupLevelActivity.LevelPayload {
    fileprivate init(_ level: GoalSetupBody.Level) {
        switch level {
        case .sedentary: self = .sedentary
        case .standing: self = .standing
        case .active: self = .active
        }
    }
}

extension Components.Schemas.GoalChoice {
    fileprivate init(_ choice: GoalDecisionRequest.Choice) {
        switch choice {
        case .maintain:
            self = .maintain(.init(_type: .maintain))
        case .proposal(let direction, let deadlineOn, let pace):
            self = .proposal(
                .init(
                    _type: .proposal, direction: direction.wire(lose: .lose, gain: .gain),
                    deadlineOn: deadlineOn, pace: .init(pace)))
        case .custom(let direction, let deadlineOn, let targetWeightKilograms):
            self = .custom(
                .init(
                    _type: .custom, direction: direction.wire(lose: .lose, gain: .gain),
                    deadlineOn: deadlineOn, targetWeightKg: targetWeightKilograms))
        }
    }
}

extension Components.Schemas.GoalProposalChoice.PacePayload {
    fileprivate init(_ pace: GoalProposals.Pace) {
        switch pace {
        case .gentle: self = .gentle
        case .standard: self = .standard
        case .hard: self = .hard
        }
    }
}

extension GoalProposals {
    fileprivate init(_ wire: Components.Schemas.GoalProposals) {
        switch wire {
        case .maintain(let maintain):
            self.init(
                maintain,
                plan: .maintenance(
                    Maintenance(
                        targetWeightKilograms: maintain.maintenance.targetWeightKg,
                        dailyGuide: DailyGuidePlan(maintain.maintenance.dailyGuide))))
        case .lose(let lose):
            self.init(lose, plan: .weightChange(WeightChange(lose, direction: .lose)))
        case .gain(let gain):
            self.init(gain, plan: .weightChange(WeightChange(gain, direction: .gain)))
        }
    }

    fileprivate init(_ basis: some GoalProposalsBasisWire, plan: Plan) {
        self.init(
            startedOn: basis.startedOn,
            expenditureKilocalories: basis.expenditureKcal,
            expenditureSource: ExpenditureSource(basis.expenditureSource),
            startingWeightTrendKilograms: basis.startingWeightTrendKg,
            lastWeightRecordedOn: basis.lastWeightRecordedOn,
            plan: plan)
    }
}

/// 目標案の応答の、向きによらない計算の元。生成した型は向きごとに別なので、まとめて読むために揃える
private protocol GoalProposalsBasisWire {
    var startedOn: String { get }
    var expenditureKcal: Int { get }
    var expenditureSource: Components.Schemas.GoalSetupExpenditureSource { get }
    var startingWeightTrendKg: Double { get }
    var lastWeightRecordedOn: String { get }
}

/// 減量・増量の目標案の応答。生成した型は向きごとに別なので、まとめて読むために揃える
private protocol WeightChangeProposalsWire: GoalProposalsBasisWire {
    var deadlineOn: String { get }
    var proposals: [Components.Schemas.GoalProposal] { get }
    var acceptedTargetWeightRange: Components.Schemas.AcceptedTargetWeightRange? { get }
}

extension Components.Schemas.MaintainGoalProposals: GoalProposalsBasisWire {}
extension Components.Schemas.LoseGoalProposals: WeightChangeProposalsWire {}
extension Components.Schemas.GainGoalProposals: WeightChangeProposalsWire {}

extension GoalProposals.ExpenditureSource {
    fileprivate init(_ wire: Components.Schemas.GoalSetupExpenditureSource) {
        switch wire {
        case .backCalculated: self = .backCalculated
        case .formula: self = .formula
        case .current: self = .current
        }
    }
}

extension GoalProposals.WeightChange {
    fileprivate init(_ wire: some WeightChangeProposalsWire, direction: GoalProposals.Direction) {
        self.init(
            direction: direction,
            deadlineOn: wire.deadlineOn,
            proposals: wire.proposals.map(GoalProposals.Proposal.init),
            acceptedTargetWeightRange: wire.acceptedTargetWeightRange.map {
                GoalProposals.AcceptedTargetWeightRange(
                    minimumKilograms: $0.minimumKg,
                    maximumKilograms: $0.maximumKg,
                    fastestEndReason: TargetWeightLimitReason(serverName: $0.fastestEndReason))
            })
    }
}

extension GoalProposals.Direction {
    /// 生成した型は要求ごとに向きの enum を持つので、減量と増量の値を受け取って選ぶ
    fileprivate func wire<Wire>(lose: Wire, gain: Wire) -> Wire {
        switch self {
        case .lose: lose
        case .gain: gain
        }
    }
}

extension GoalProposals.Proposal {
    fileprivate init(_ wire: Components.Schemas.GoalProposal) {
        switch wire {
        case .offered(let offered):
            self = .offered(
                GoalProposals.OfferedProposal(
                    pace: GoalProposals.Pace(offered.pace),
                    targetWeightKilograms: offered.targetWeightKg,
                    dailyGuide: DailyGuidePlan(offered.dailyGuide),
                    difficulty: GoalProposals.Pace(offered.difficulty),
                    dailyGuideDifferenceKilocalories: offered.dailyGuideDifferenceKcal))
        case .unavailable(let unavailable):
            self = .unavailable(
                pace: GoalProposals.Pace(unavailable.pace),
                reason: GoalProposals.UnavailableReason(serverName: unavailable.unavailableReason))
        }
    }
}

extension GoalProposals.Pace {
    fileprivate init(_ wire: Components.Schemas.ProposalPace) {
        switch wire {
        case .gentle: self = .gentle
        case .standard: self = .standard
        case .hard: self = .hard
        }
    }
}

extension CustomTargetWeightAssessment {
    fileprivate init(_ wire: Components.Schemas.CustomTargetWeightAssessment) {
        switch wire {
        case .accepted(let accepted):
            self.init(
                startedOn: accepted.startedOn,
                outcome: .accepted(
                    Accepted(
                        dailyGuide: DailyGuidePlan(accepted.dailyGuide),
                        difficulty: GoalProposals.Pace(accepted.difficulty),
                        dailyGuideDifferenceKilocalories: accepted.dailyGuideDifferenceKcal)))
        case .rejected(let rejected):
            self.init(
                startedOn: rejected.startedOn,
                outcome: .rejected(
                    reason: TargetWeightLimitReason(serverName: rejected.rejectionReason),
                    nearestAcceptedTargetWeightKilograms: rejected.nearestAcceptedTargetWeightKg))
        }
    }
}

extension GoalDecision {
    fileprivate init(_ wire: Components.Schemas.GoalDecision) {
        switch wire {
        case .decided(let decided):
            self = .decided(
                decided.changes.map {
                    RecordKindWireCodings.change(
                        wireKind: $0.kind, recordId: $0.recordId, record: $0.record)
                })
        case .recalculated(let recalculated):
            self = .recalculated(GoalProposals(recalculated.proposals))
        case .customTargetWeightRejected(let rejected):
            self = .customTargetWeightRejected(
                startedOn: rejected.startedOn,
                reason: TargetWeightLimitReason(serverName: rejected.rejectionReason),
                nearestAcceptedTargetWeightKilograms: rejected.nearestAcceptedTargetWeightKg)
        }
    }
}
