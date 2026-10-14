#if DEBUG
    import NuToriAPI
    import NuToriCore
    import SwiftUI

    #Preview("状態ごと", arguments: GoalSetupFlowCard.Sample.allCases) { sample in
        ScrollView {
            GoalSetupFlowCard(
                content: sample.content, actions: .none, timeZone: DeviceClock.live.timeZone
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    extension GoalSetupFlowCard {
        fileprivate enum Sample: CaseIterable {
            case direction
            case deadline
            /// 次が足りない値か目標案かが分かるまで、下見の答えを待つ
            case awaitingPreview
            case missingValues
            /// 目標案が届くまで。届く場所の高さを取って回る印を出す
            case proposalsWaiting
            /// 逆算できない人の目標案。上の1行に使った値と「変える」、最後の体重記録の日
            case proposals
            /// 決めずに新しい案が返り、計算し直した1行を添えた
            case proposalsRecalculated
            /// 目標を決める要求が届かなかった
            case proposalsDecisionUnreachable
            /// 「この目標で始める」を押して待っている
            case proposalsDeciding
            /// 自分で決める目標体重の答えを待っている
            case customTargetWeightAssessing
            /// 自分で決める目標体重を端の値に直し、答えが届かなかった
            case customTargetWeightUnreachable
            case maintenance
            case loseUnavailable
            case stoppedBeforeMissingValues
            case stoppedBeforeProposals

            var content: GoalSetupFlowContent {
                GoalSetupFlowContent(
                    page: page, progress: progress, direction: direction,
                    deadline: Self.choices.initialDay, deadlineChoices: Self.choices,
                    missingValues: missingValues, proposals: proposals,
                    selectedPace: proposals == nil ? nil : .standard,
                    customTargetWeight: customTargetWeight, decision: decision,
                    unreachableRequest: unreachableRequest,
                    showsRecalculated: showsRecalculated, usedValues: usedValues,
                    pastWeightRecordDay: pastWeightRecordDay)
            }

            private static let choices = GoalDeadlineChoices(startDay: .sampleToday)

            private static let body = GoalSetupBody(
                sex: .female, heightCentimeters: 160, ageYears: 35, activity: .level(.standing))

            private var page: GoalSetupPage {
                switch self {
                case .direction: .direction
                case .deadline: .deadline
                case .awaitingPreview: .awaitingPreview
                case .missingValues: .missingValues
                case .proposalsWaiting, .proposals, .proposalsRecalculated,
                    .proposalsDecisionUnreachable, .proposalsDeciding:
                    .proposals
                case .customTargetWeightAssessing, .customTargetWeightUnreachable:
                    .customTargetWeight
                case .maintenance: .maintenance
                case .loseUnavailable: .loseUnavailable
                case .stoppedBeforeMissingValues: .stopped(.beforeMissingValues)
                case .stoppedBeforeProposals: .stopped(.beforeProposals)
                }
            }

            private var progress: GoalSetupFlow.Progress {
                switch self {
                case .direction: .init(count: 3, index: 0)
                case .deadline, .awaitingPreview, .stoppedBeforeMissingValues:
                    .init(count: 3, index: 1)
                case .missingValues: .init(count: 4, index: 2)
                case .maintenance, .loseUnavailable: .init(count: 2, index: 1)
                case .proposals: .init(count: 4, index: 3)
                case .proposalsWaiting, .proposalsRecalculated, .proposalsDecisionUnreachable,
                    .proposalsDeciding, .customTargetWeightAssessing,
                    .customTargetWeightUnreachable, .stoppedBeforeProposals:
                    .init(count: 3, index: 2)
                }
            }

            private var direction: GoalSetupDirection? {
                switch self {
                case .direction: nil
                case .maintenance: .maintain
                case .deadline, .awaitingPreview, .missingValues, .proposalsWaiting, .proposals,
                    .proposalsRecalculated, .proposalsDecisionUnreachable, .proposalsDeciding,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable, .loseUnavailable,
                    .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    .lose
                }
            }

            private var showsRecalculated: Bool {
                switch self {
                case .proposalsRecalculated: true
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .proposals, .proposalsDecisionUnreachable, .proposalsDeciding,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable, .maintenance,
                    .loseUnavailable, .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    false
                }
            }

            /// 逆算できない人の目標案だけが、足りない値で決めた身体データと最後の体重記録の日を見せる
            private var usedValues: GoalSetupUsedValues? {
                if isFormulaProposals { return .formula(Self.body, weightKilograms: 70.0) }
                return proposals.map {
                    .backCalculated(expenditureKilocalories: $0.expenditureKilocalories)
                }
            }

            private var pastWeightRecordDay: CalendarDay? {
                isFormulaProposals ? CalendarDay.sampleToday.advanced(by: -2) : nil
            }

            private var isFormulaProposals: Bool {
                switch self {
                case .proposals: true
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .proposalsRecalculated, .proposalsDecisionUnreachable, .proposalsDeciding,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable, .maintenance,
                    .loseUnavailable, .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    false
                }
            }

            private var missingValues: GoalSetupMissingValues? {
                switch self {
                case .missingValues:
                    GoalSetupMissingValues(
                        health: HealthBodyData(
                            heightCentimeters: nil, age: 35, sex: nil, dailySteps: [:]),
                        asksCurrentWeight: true, today: .sampleToday)
                case .direction, .deadline, .awaitingPreview, .proposalsWaiting, .proposals,
                    .proposalsRecalculated, .proposalsDecisionUnreachable, .proposalsDeciding,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable, .maintenance,
                    .loseUnavailable, .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    nil
                }
            }

            private var proposals: GoalProposals? {
                switch self {
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .loseUnavailable, .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    nil
                case .maintenance:
                    Self.proposals(
                        plan: .maintenance(
                            .init(targetWeightKilograms: 65.0, dailyGuide: Self.dailyGuide(2250))),
                        source: .backCalculated)
                case .proposals:
                    Self.proposals(plan: .weightChange(Self.weightChange), source: .formula)
                case .proposalsRecalculated, .proposalsDecisionUnreachable, .proposalsDeciding,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable:
                    Self.proposals(plan: .weightChange(Self.weightChange), source: .backCalculated)
                }
            }

            private var customTargetWeight: CustomTargetWeight? {
                switch self {
                case .customTargetWeightAssessing:
                    Self.custom(kilograms: 66.0, correctedReason: nil, isAssessing: true)
                case .customTargetWeightUnreachable:
                    Self.custom(kilograms: 64.0, correctedReason: .paceTooFast, isAssessing: false)
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .proposals, .proposalsRecalculated, .proposalsDecisionUnreachable,
                    .proposalsDeciding, .maintenance, .loseUnavailable, .stoppedBeforeMissingValues,
                    .stoppedBeforeProposals:
                    nil
                }
            }

            private var decision: GoalSetupFlow.Decision {
                switch self {
                case .proposalsDeciding: .deciding
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .proposals, .proposalsRecalculated, .proposalsDecisionUnreachable,
                    .customTargetWeightAssessing, .customTargetWeightUnreachable, .maintenance,
                    .loseUnavailable, .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    .idle
                }
            }

            private var unreachableRequest: GoalSetupFlow.UnreachableRequest? {
                switch self {
                case .proposalsDecisionUnreachable: .decision
                case .customTargetWeightUnreachable: .customTargetWeight
                case .direction, .deadline, .awaitingPreview, .missingValues, .proposalsWaiting,
                    .proposals, .proposalsRecalculated, .proposalsDeciding,
                    .customTargetWeightAssessing, .maintenance, .loseUnavailable,
                    .stoppedBeforeMissingValues, .stoppedBeforeProposals:
                    nil
                }
            }

            private static let weightChange = GoalProposals.WeightChange(
                direction: .lose, deadlineOn: choices.initialDay.yearMonthDay,
                proposals: [
                    offered(.gentle, 68.5, 2050), offered(.standard, 66.5, 1850),
                    .unavailable(pace: .hard, reason: .dailyGuideBelowMinimum),
                ],
                acceptedTargetWeightRange: .init(
                    minimumKilograms: 64.0, maximumKilograms: 69.9,
                    fastestEndReason: .dailyGuideBelowMinimum))

            private static func proposals(
                plan: GoalProposals.Plan, source: GoalProposals.ExpenditureSource
            ) -> GoalProposals {
                GoalProposals(
                    startedOn: CalendarDay.sampleToday.yearMonthDay, expenditureKilocalories: 2250,
                    expenditureSource: source, startingWeightTrendKilograms: 70.0,
                    lastWeightRecordedOn: CalendarDay.sampleToday.yearMonthDay, plan: plan)
            }

            private static func offered(
                _ pace: GoalProposals.Pace, _ kilograms: Double, _ energy: Int
            ) -> GoalProposals.Proposal {
                .offered(
                    .init(
                        pace: pace, targetWeightKilograms: kilograms,
                        dailyGuide: dailyGuide(energy), difficulty: pace,
                        dailyGuideDifferenceKilocalories: energy - 2250))
            }

            private static func custom(
                kilograms: Double, correctedReason: TargetWeightLimitReason?, isAssessing: Bool
            ) -> CustomTargetWeight {
                CustomTargetWeight(
                    kilograms: kilograms, direction: .lose,
                    range: .init(
                        minimumKilograms: 64.0, maximumKilograms: 69.9,
                        fastestEndReason: .paceTooFast),
                    correctedReason: correctedReason,
                    assessment: .init(
                        dailyGuide: dailyGuide(1800), difficulty: .standard,
                        dailyGuideDifferenceKilocalories: -450),
                    isAssessing: isAssessing)
            }

            private static func dailyGuide(_ energy: Int) -> DailyGuidePlan {
                DailyGuidePlan(
                    energyKilocalories: energy, proteinGrams: 105, fatGrams: 50,
                    carbohydrateGrams: 240)
            }
        }
    }
#endif
