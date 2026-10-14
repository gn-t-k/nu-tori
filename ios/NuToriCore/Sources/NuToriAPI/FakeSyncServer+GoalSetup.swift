#if DEBUG
    public import Foundation
    import HTTPTypes
    import OpenAPIRuntime

    extension FakeSyncServer {
        /// 目標の設定の4つの要求への答え方。計算はせず、場面が決めた値を返す
        public struct GoalSetupAnswers: Sendable {
            public let preview: GoalSetupPreview
            /// 向きと期限（YYYY-MM-DD。維持は nil）から作る目標案
            public let proposals:
                @Sendable (_ direction: GoalSetupDirection, _ deadlineOn: String?)
                    -> GoalProposals
            /// 期限と目標体重から作る、自分で決める目標体重の答え
            public let assessCustomTargetWeight:
                @Sendable (_ deadlineOn: String, _ targetWeightKilograms: Double)
                    -> CustomTargetWeightAssessment.Outcome
            /// 決めた目標の `decidedAt` と推定の `estimatedAt`
            public let now: @Sendable () -> Date

            public init(
                preview: GoalSetupPreview,
                proposals:
                    @escaping @Sendable (_ direction: GoalSetupDirection, _ deadlineOn: String?)
                    -> GoalProposals,
                assessCustomTargetWeight:
                    @escaping @Sendable (_ deadlineOn: String, _ targetWeightKilograms: Double)
                    -> CustomTargetWeightAssessment.Outcome,
                now: @escaping @Sendable () -> Date
            ) {
                self.preview = preview
                self.proposals = proposals
                self.assessCustomTargetWeight = assessCustomTargetWeight
                self.now = now
            }
        }

        /// 目標の設定の要求に答える。答え方が無い場面は 404（流れは止まるページへ）
        func respondToGoalSetup(operationID: String, body: HTTPBody?) async throws -> (
            HTTPResponse, HTTPBody?
        ) {
            guard let answers = scenario.goalSetup else {
                return (HTTPResponse(status: .notFound), nil)
            }
            guard let body else { throw MissingBodyError() }
            let data = try await Data(collecting: body, upTo: 1_048_576)
            let decoder = JSONDecoder()
            switch operationID {
            case Operations.PreviewGoalSetup.id:
                return try json(
                    .ok,
                    Components.Schemas.GoalSetupPreview(
                        canBackCalculate: answers.preview.canBackCalculate,
                        canOfferLoseProposals: answers.preview.canOfferLoseProposals))
            case Operations.ProposeGoals.id:
                let request = try decoder.decode(
                    Operations.ProposeGoals.Input.Body.JsonPayload.self, from: data)
                return try json(
                    .ok,
                    Components.Schemas.GoalProposals(
                        answers.proposals(
                            GoalSetupDirection(serverName: request.direction.rawValue),
                            request.deadlineOn)))
            case Operations.AssessCustomTargetWeight.id:
                let request = try decoder.decode(
                    Operations.AssessCustomTargetWeight.Input.Body.JsonPayload.self, from: data)
                let proposals = answers.proposals(
                    GoalSetupDirection(serverName: request.direction.rawValue), request.deadlineOn)
                return try jsonObject(
                    customTargetWeightAssessment(
                        startedOn: proposals.startedOn,
                        outcome: answers.assessCustomTargetWeight(
                            request.deadlineOn, request.targetWeightKg)))
            case Operations.DecideGoal.id:
                let request = try decoder.decode(
                    Operations.DecideGoal.Input.Body.JsonPayload.self, from: data)
                let changes = decidedChanges(request, answers: answers)
                record(changes)
                return try json(
                    .ok,
                    Components.Schemas.GoalDecision(
                        status: "decided",
                        changes: try changes.map(Components.Schemas.GoalDecisionChange.init)))
            default:
                return (HTTPResponse(status: .notFound), nil)
            }
        }

        /// いつも決める。記録は初めての目標の並び（目標、1日の目安、推定消費カロリー）で、見せていた値で作る
        private func decidedChanges(
            _ request: Operations.DecideGoal.Input.Body.JsonPayload, answers: GoalSetupAnswers
        ) -> [SyncChange] {
            let direction: SyncedGoal.Direction
            let proposalsDirection: GoalSetupDirection
            switch request.choice {
            case .maintain:
                direction = .maintain
                proposalsDirection = .maintain
            case .proposal(let choice):
                let weightChange = SyncedGoal.WeightChange(
                    deadlineOn: choice.deadlineOn,
                    pacePlan: SyncedGoal.PacePlan(rawValue: choice.pace.rawValue) ?? .standard)
                direction = choice.direction == .lose ? .lose(weightChange) : .gain(weightChange)
                proposalsDirection = choice.direction == .lose ? .lose : .gain
            case .custom(let choice):
                let weightChange = SyncedGoal.WeightChange(
                    deadlineOn: choice.deadlineOn, pacePlan: .custom)
                direction = choice.direction == .lose ? .lose(weightChange) : .gain(weightChange)
                proposalsDirection = choice.direction == .lose ? .lose : .gain
            }
            let proposals = answers.proposals(
                proposalsDirection, direction.weightChange?.deadlineOn)
            let now = answers.now()
            let goalId = UUID()
            let estimateId = UUID()
            let guide = request.shown.dailyGuide
            return [
                .goal(
                    SyncedGoal(
                        id: goalId, startedOn: request.startedOn,
                        startingWeightTrendKilograms: proposals.startingWeightTrendKilograms,
                        targetWeightKilograms: request.shown.targetWeightKg, decidedAt: now,
                        timeZone: TimeZone(identifier: request.timeZone) ?? .current,
                        direction: direction, closure: nil)),
                .dailyGuide(
                    SyncedDailyGuide(
                        id: UUID(), goalId: goalId, expenditureEstimateId: estimateId,
                        effectiveOn: request.startedOn, energyKilocalories: guide.energyKcal,
                        proteinGrams: guide.proteinG, fatGrams: guide.fatG,
                        carbohydrateGrams: guide.carbohydrateG, limitHits: [])),
                .expenditureEstimate(
                    SyncedExpenditureEstimate(
                        id: estimateId, effectiveOn: request.startedOn,
                        expenditureKilocalories: proposals.expenditureKilocalories,
                        estimatedAt: now,
                        initialSource: proposals.expenditureSource == .formula
                            ? .formula : .backCalculated)),
            ]
        }

        /// 1日の目安が allOf の入れ物なので、生成した型を通さずに書く
        private func customTargetWeightAssessment(
            startedOn: String, outcome: CustomTargetWeightAssessment.Outcome
        ) -> [String: Any] {
            switch outcome {
            case .accepted(let accepted):
                return [
                    "startedOn": startedOn, "status": "accepted",
                    "dailyGuide": [
                        "energyKcal": accepted.dailyGuide.energyKilocalories,
                        "proteinG": accepted.dailyGuide.proteinGrams,
                        "fatG": accepted.dailyGuide.fatGrams,
                        "carbohydrateG": accepted.dailyGuide.carbohydrateGrams,
                    ],
                    "difficulty": accepted.difficulty.rawValue,
                    "dailyGuideDifferenceKcal": accepted.dailyGuideDifferenceKilocalories,
                ]
            case .rejected(let reason, let nearest):
                var object: [String: Any] = [
                    "startedOn": startedOn, "status": "rejected",
                    "rejectionReason": reason.serverName,
                ]
                object["nearestAcceptedTargetWeightKg"] = nearest
                return object
            }
        }

        private func jsonObject(_ object: [String: Any]) throws -> (HTTPResponse, HTTPBody?) {
            var response = HTTPResponse(status: .ok)
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(try JSONSerialization.data(withJSONObject: object)))
        }
    }

    extension GoalSetupDirection {
        fileprivate init(serverName: String) {
            switch serverName {
            case "lose": self = .lose
            case "gain": self = .gain
            default: self = .maintain
            }
        }
    }

    extension TargetWeightLimitReason {
        fileprivate var serverName: String {
            switch self {
            case .paceTooFast: "pace_too_fast"
            case .dailyGuideBelowMinimum: "daily_guide_below_minimum"
            case .notOnDirectionSide: "not_on_direction_side"
            case .unknown(let name): name
            }
        }
    }

    extension Components.Schemas.GoalProposals {
        fileprivate init(_ proposals: GoalProposals) {
            let source =
                switch proposals.expenditureSource {
                case .backCalculated: "back_calculated"
                case .formula: "formula"
                case .current: "current"
                }
            switch proposals.plan {
            case .maintenance(let maintenance):
                self.init(
                    startedOn: proposals.startedOn, direction: "maintain",
                    expenditureKcal: proposals.expenditureKilocalories, expenditureSource: source,
                    startingWeightTrendKg: proposals.startingWeightTrendKilograms,
                    lastWeightRecordedOn: proposals.lastWeightRecordedOn,
                    maintenance: .init(
                        targetWeightKg: maintenance.targetWeightKilograms,
                        dailyGuide: .init(maintenance.dailyGuide)))
            case .weightChange(let weightChange):
                self.init(
                    startedOn: proposals.startedOn,
                    direction: weightChange.direction == .lose ? "lose" : "gain",
                    expenditureKcal: proposals.expenditureKilocalories, expenditureSource: source,
                    startingWeightTrendKg: proposals.startingWeightTrendKilograms,
                    lastWeightRecordedOn: proposals.lastWeightRecordedOn,
                    deadlineOn: weightChange.deadlineOn,
                    proposals: weightChange.proposals.map(Components.Schemas.GoalProposal.init),
                    acceptedTargetWeightRange: weightChange.acceptedTargetWeightRange.map {
                        .init(
                            minimumKg: $0.minimumKilograms, maximumKg: $0.maximumKilograms,
                            fastestEndReason: $0.fastestEndReason.serverName)
                    })
            }
        }
    }

    extension Components.Schemas.GoalProposal {
        fileprivate init(_ proposal: GoalProposals.Proposal) {
            switch proposal.availability {
            case .offered(let offered):
                self.init(
                    pace: proposal.pace.rawValue, status: "offered",
                    targetWeightKg: offered.targetWeightKilograms,
                    dailyGuide: .init(offered.dailyGuide),
                    difficulty: offered.difficulty.rawValue,
                    dailyGuideDifferenceKcal: offered.dailyGuideDifferenceKilocalories)
            case .unavailable(let reason):
                let name =
                    switch reason {
                    case .dailyGuideBelowMinimum: "daily_guide_below_minimum"
                    case .unknown(let name): name
                    }
                self.init(
                    pace: proposal.pace.rawValue, status: "unavailable",
                    unavailableReason: name)
            }
        }
    }

    extension Components.Schemas.DailyGuidePlan {
        fileprivate init(_ plan: DailyGuidePlan) {
            self.init(
                energyKcal: plan.energyKilocalories, proteinG: plan.proteinGrams,
                fatG: plan.fatGrams, carbohydrateG: plan.carbohydrateGrams)
        }
    }
#endif
