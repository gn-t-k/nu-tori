#if DEBUG
    public import Foundation
    import HTTPTypes
    import OpenAPIRuntime

    extension FakeSyncServer {
        /// 目標の設定の4つの要求への答え方。計算はせず、場面が決めた値を返す
        public struct GoalSetupAnswers: Sendable {
            public let preview: GoalSetupPreview
            /// 向きと期限から作る目標案
            public let proposals: @Sendable (_ plan: GoalProposalsPlan) -> GoalProposals
            /// 期限と目標体重から作る、自分で決める目標体重の答え
            public let assessCustomTargetWeight:
                @Sendable (_ deadlineOn: String, _ targetWeightKilograms: Double)
                    -> CustomTargetWeightAssessment.Outcome
            /// 決めた目標の `decidedAt` と推定の `estimatedAt`
            public let now: @Sendable () -> Date

            public init(
                preview: GoalSetupPreview,
                proposals: @escaping @Sendable (_ plan: GoalProposalsPlan) -> GoalProposals,
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
                        answers.proposals(GoalProposalsPlan(request.plan))))
            case Operations.AssessCustomTargetWeight.id:
                let request = try decoder.decode(
                    Operations.AssessCustomTargetWeight.Input.Body.JsonPayload.self, from: data)
                let proposals = answers.proposals(
                    .weightChange(
                        direction: GoalProposals.Direction(request.direction),
                        deadlineOn: request.deadlineOn))
                return try json(
                    .ok,
                    Components.Schemas.CustomTargetWeightAssessment(
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
                    Components.Schemas.GoalDecision.decided(
                        .init(
                            status: .decided,
                            changes: try changes.map(Components.Schemas.GoalDecisionChange.init))))
            // swiftlint:disable:next no_default_in_switch - 操作の ID は文字列で、偽のサーバーが持たない操作が来る
            default:
                return (HTTPResponse(status: .notFound), nil)
            }
        }

        /// いつも決める。記録は初めての目標の並び（目標、1日の目安、推定消費カロリー）で、見せていた値で作る
        private func decidedChanges(
            _ request: Operations.DecideGoal.Input.Body.JsonPayload, answers: GoalSetupAnswers
        ) -> [SyncChange] {
            let direction: SyncedGoal.Direction
            let plan: GoalProposalsPlan
            switch request.choice {
            case .maintain:
                direction = .maintain
                plan = .maintain
            case .proposal(let choice):
                (direction, plan) = Self.weightChange(
                    GoalProposals.Direction(choice.direction),
                    SyncedGoal.WeightChange(
                        deadlineOn: choice.deadlineOn,
                        pacePlan: SyncedGoal.PacePlan(choice.pace)))
            case .custom(let choice):
                (direction, plan) = Self.weightChange(
                    GoalProposals.Direction(choice.direction),
                    SyncedGoal.WeightChange(deadlineOn: choice.deadlineOn, pacePlan: .custom))
            }
            let proposals = answers.proposals(plan)
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

        private static func weightChange(
            _ direction: GoalProposals.Direction, _ weightChange: SyncedGoal.WeightChange
        ) -> (SyncedGoal.Direction, GoalProposalsPlan) {
            switch direction {
            case .lose:
                (
                    .lose(weightChange),
                    .weightChange(direction: .lose, deadlineOn: weightChange.deadlineOn)
                )
            case .gain:
                (
                    .gain(weightChange),
                    .weightChange(direction: .gain, deadlineOn: weightChange.deadlineOn)
                )
            }
        }
    }

    extension GoalProposalsPlan {
        fileprivate init(_ wire: Components.Schemas.GoalProposalsPlan) {
            switch wire {
            case .maintain: self = .maintain
            case .lose(let lose):
                self = .weightChange(direction: .lose, deadlineOn: lose.deadlineOn)
            case .gain(let gain):
                self = .weightChange(direction: .gain, deadlineOn: gain.deadlineOn)
            }
        }
    }

    extension GoalProposals.Direction {
        /// 生成した型は要求ごとに向きの enum を持つので、文字列で読む。減量と増量しか届かない
        fileprivate init<Wire: RawRepresentable<String>>(_ wire: Wire) {
            switch wire.rawValue {
            case "lose": self = .lose
            case "gain": self = .gain
            // swiftlint:disable:next no_default_in_switch - 生成した型は要求ごとに別の enum なので、文字列で読む
            default: preconditionFailure("目標の設定の要求に、減量と増量のほかの向きが届いた: \(wire.rawValue)")
            }
        }
    }

    extension SyncedGoal.PacePlan {
        fileprivate init(_ wire: Components.Schemas.GoalProposalChoice.PacePayload) {
            switch wire {
            case .gentle: self = .gentle
            case .standard: self = .standard
            case .hard: self = .hard
            }
        }
    }

    extension Components.Schemas.GoalProposals {
        fileprivate init(_ proposals: GoalProposals) {
            let source: Components.Schemas.GoalSetupExpenditureSource =
                switch proposals.expenditureSource {
                case .backCalculated: .backCalculated
                case .formula: .formula
                case .current: .current
                }
            switch proposals.plan {
            case .maintenance(let maintenance):
                self = .maintain(
                    .init(
                        startedOn: proposals.startedOn,
                        expenditureKcal: proposals.expenditureKilocalories,
                        expenditureSource: source,
                        startingWeightTrendKg: proposals.startingWeightTrendKilograms,
                        lastWeightRecordedOn: proposals.lastWeightRecordedOn,
                        direction: .maintain,
                        maintenance: .init(
                            targetWeightKg: maintenance.targetWeightKilograms,
                            dailyGuide: .init(maintenance.dailyGuide))))
            case .weightChange(let weightChange):
                let proposalsOfPlan = weightChange.proposals.map(
                    Components.Schemas.GoalProposal.init)
                let range = weightChange.acceptedTargetWeightRange.map {
                    Components.Schemas.AcceptedTargetWeightRange(
                        minimumKg: $0.minimumKilograms, maximumKg: $0.maximumKilograms,
                        fastestEndReason: $0.fastestEndReason.serverName)
                }
                switch weightChange.direction {
                case .lose:
                    self = .lose(
                        .init(
                            startedOn: proposals.startedOn,
                            expenditureKcal: proposals.expenditureKilocalories,
                            expenditureSource: source,
                            startingWeightTrendKg: proposals.startingWeightTrendKilograms,
                            lastWeightRecordedOn: proposals.lastWeightRecordedOn,
                            deadlineOn: weightChange.deadlineOn,
                            proposals: proposalsOfPlan,
                            acceptedTargetWeightRange: range,
                            direction: .lose))
                case .gain:
                    self = .gain(
                        .init(
                            startedOn: proposals.startedOn,
                            expenditureKcal: proposals.expenditureKilocalories,
                            expenditureSource: source,
                            startingWeightTrendKg: proposals.startingWeightTrendKilograms,
                            lastWeightRecordedOn: proposals.lastWeightRecordedOn,
                            deadlineOn: weightChange.deadlineOn,
                            proposals: proposalsOfPlan,
                            acceptedTargetWeightRange: range,
                            direction: .gain))
                }
            }
        }
    }

    extension Components.Schemas.GoalProposal {
        fileprivate init(_ proposal: GoalProposals.Proposal) {
            switch proposal {
            case .offered(let offered):
                self = .offered(
                    .init(
                        pace: .init(offered.pace), status: .offered,
                        targetWeightKg: offered.targetWeightKilograms,
                        dailyGuide: .init(offered.dailyGuide),
                        difficulty: .init(offered.difficulty),
                        dailyGuideDifferenceKcal: offered.dailyGuideDifferenceKilocalories))
            case .unavailable(let pace, let reason):
                self = .unavailable(
                    .init(
                        pace: .init(pace), status: .unavailable,
                        unavailableReason: reason.serverName))
            }
        }
    }

    extension Components.Schemas.CustomTargetWeightAssessment {
        fileprivate init(startedOn: String, outcome: CustomTargetWeightAssessment.Outcome) {
            switch outcome {
            case .accepted(let accepted):
                self = .accepted(
                    .init(
                        startedOn: startedOn, status: .accepted,
                        dailyGuide: .init(accepted.dailyGuide),
                        difficulty: .init(accepted.difficulty),
                        dailyGuideDifferenceKcal: accepted.dailyGuideDifferenceKilocalories))
            case .rejected(let reason, let nearest):
                self = .rejected(
                    .init(
                        startedOn: startedOn, status: .rejected,
                        rejectionReason: reason.serverName,
                        nearestAcceptedTargetWeightKg: nearest))
            }
        }
    }

    extension Components.Schemas.ProposalPace {
        fileprivate init(_ pace: GoalProposals.Pace) {
            switch pace {
            case .gentle: self = .gentle
            case .standard: self = .standard
            case .hard: self = .hard
            }
        }
    }

#endif
