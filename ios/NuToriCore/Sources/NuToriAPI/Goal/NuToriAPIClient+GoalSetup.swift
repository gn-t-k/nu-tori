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
        case .ok(let ok): return .answered(try GoalProposals(try ok.body.json))
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
        case .ok(let ok): return .answered(try CustomTargetWeightAssessment(try ok.body.json))
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
        case .ok(let ok): return .answered(try GoalDecision(try ok.body.json))
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

extension Components.Schemas.DailyGuidePlan {
    fileprivate init(_ plan: DailyGuidePlan) {
        self.init(
            energyKcal: plan.energyKilocalories, proteinG: plan.proteinGrams, fatG: plan.fatGrams,
            carbohydrateG: plan.carbohydrateGrams)
    }
}

extension DailyGuidePlan {
    fileprivate init(_ plan: Components.Schemas.DailyGuidePlan) {
        self.init(
            energyKilocalories: plan.energyKcal, proteinGrams: plan.proteinG, fatGrams: plan.fatG,
            carbohydrateGrams: plan.carbohydrateG)
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
    /// 知らない向き・出どころ・速さ・状態は、どう見せるか決められないので投げる
    fileprivate init(_ wire: Components.Schemas.GoalProposals) throws {
        let source: ExpenditureSource =
            switch wire.expenditureSource {
            case "back_calculated": .backCalculated
            case "formula": .formula
            case "current": .current
            default:
                throw NuToriAPIClient.MalformedResponseError(reason: "知らない推定消費カロリーの出どころ")
            }
        let plan: Plan
        switch wire.direction {
        case "maintain":
            guard let maintenance = wire.maintenance else {
                throw NuToriAPIClient.MalformedResponseError(reason: "維持の目標体重が無い")
            }
            plan = .maintenance(
                Maintenance(
                    targetWeightKilograms: maintenance.targetWeightKg,
                    dailyGuide: DailyGuidePlan(maintenance.dailyGuide)))
        case "lose":
            plan = .weightChange(try WeightChange(wire, direction: .lose))
        case "gain":
            plan = .weightChange(try WeightChange(wire, direction: .gain))
        default:
            throw NuToriAPIClient.MalformedResponseError(reason: "知らない向き")
        }
        self.init(
            startedOn: wire.startedOn,
            expenditureKilocalories: wire.expenditureKcal,
            expenditureSource: source,
            startingWeightTrendKilograms: wire.startingWeightTrendKg,
            lastWeightRecordedOn: wire.lastWeightRecordedOn,
            plan: plan)
    }
}

extension GoalProposals.WeightChange {
    fileprivate init(_ wire: Components.Schemas.GoalProposals, direction: GoalProposals.Direction)
        throws
    {
        guard let deadlineOn = wire.deadlineOn, let proposals = wire.proposals else {
            throw NuToriAPIClient.MalformedResponseError(reason: "期限か目標案が無い")
        }
        self.init(
            direction: direction,
            deadlineOn: deadlineOn,
            proposals: try proposals.map(GoalProposals.Proposal.init),
            acceptedTargetWeightRange: wire.acceptedTargetWeightRange.map {
                GoalProposals.AcceptedTargetWeightRange(
                    minimumKilograms: $0.minimumKg,
                    maximumKilograms: $0.maximumKg,
                    fastestEndReason: TargetWeightLimitReason($0.fastestEndReason))
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
    fileprivate init(_ wire: Components.Schemas.GoalProposal) throws {
        let pace = try GoalProposals.Pace(wireName: wire.pace)
        switch wire.status {
        case "offered":
            guard let targetWeightKg = wire.targetWeightKg, let dailyGuide = wire.dailyGuide,
                let difficulty = wire.difficulty, let difference = wire.dailyGuideDifferenceKcal
            else {
                throw NuToriAPIClient.MalformedResponseError(reason: "出せる案の値が無い")
            }
            self = .offered(
                GoalProposals.OfferedProposal(
                    pace: pace,
                    targetWeightKilograms: targetWeightKg,
                    dailyGuide: DailyGuidePlan(dailyGuide),
                    difficulty: try GoalProposals.Pace(wireName: difficulty),
                    dailyGuideDifferenceKilocalories: difference))
        case "unavailable":
            let reason: GoalProposals.UnavailableReason =
                switch wire.unavailableReason {
                case "daily_guide_below_minimum": .dailyGuideBelowMinimum
                case let other: .unknown(other ?? "")
                }
            self = .unavailable(pace: pace, reason: reason)
        default:
            throw NuToriAPIClient.MalformedResponseError(reason: "知らない案の状態")
        }
    }
}

extension GoalProposals.Pace {
    fileprivate init(wireName: String) throws {
        guard let pace = Self(rawValue: wireName) else {
            throw NuToriAPIClient.MalformedResponseError(reason: "知らない速さの案")
        }
        self = pace
    }
}

extension TargetWeightLimitReason {
    fileprivate init(_ wireName: String) {
        switch wireName {
        case "pace_too_fast": self = .paceTooFast
        case "daily_guide_below_minimum": self = .dailyGuideBelowMinimum
        case "not_on_direction_side": self = .notOnDirectionSide
        default: self = .unknown(wireName)
        }
    }
}

extension CustomTargetWeightAssessment {
    fileprivate init(_ wire: Components.Schemas.CustomTargetWeightAssessment) throws {
        switch wire.status {
        case "accepted":
            guard let dailyGuide = wire.dailyGuide, let difficulty = wire.difficulty,
                let difference = wire.dailyGuideDifferenceKcal
            else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けた目標体重の値が無い")
            }
            self.init(
                startedOn: wire.startedOn,
                outcome: .accepted(
                    Accepted(
                        dailyGuide: DailyGuidePlan(dailyGuide.value1),
                        difficulty: try GoalProposals.Pace(wireName: difficulty),
                        dailyGuideDifferenceKilocalories: difference)))
        case "rejected":
            guard let reason = wire.rejectionReason else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けない理由が無い")
            }
            self.init(
                startedOn: wire.startedOn,
                outcome: .rejected(
                    reason: TargetWeightLimitReason(reason),
                    nearestAcceptedTargetWeightKilograms: wire.nearestAcceptedTargetWeightKg))
        default:
            throw NuToriAPIClient.MalformedResponseError(reason: "知らない目標体重の答え")
        }
    }
}

extension GoalDecision {
    fileprivate init(_ wire: Components.Schemas.GoalDecision) throws {
        switch wire.status {
        case "decided":
            guard let changes = wire.changes else {
                throw NuToriAPIClient.MalformedResponseError(reason: "決めた記録が無い")
            }
            self = .decided(
                changes.map {
                    RecordKindWireCodings.change(
                        wireKind: $0.kind, recordId: $0.recordId, record: $0.record)
                })
        case "recalculated":
            guard let proposals = wire.proposals else {
                throw NuToriAPIClient.MalformedResponseError(reason: "計算し直した目標案が無い")
            }
            self = .recalculated(try GoalProposals(proposals.value1))
        case "custom_target_weight_rejected":
            guard let startedOn = wire.startedOn, let reason = wire.rejectionReason else {
                throw NuToriAPIClient.MalformedResponseError(reason: "受け付けない理由が無い")
            }
            self = .customTargetWeightRejected(
                startedOn: startedOn, reason: TargetWeightLimitReason(reason),
                nearestAcceptedTargetWeightKilograms: wire.nearestAcceptedTargetWeightKg)
        default:
            throw NuToriAPIClient.MalformedResponseError(reason: "知らない決めた答え")
        }
    }
}
