#if DEBUG
    import NuToriCore

    extension GoalSetupSession {
        /// プレビューの見本。開こうとしても状況を読めず、広げない（流れは要求のクライアントとヘルスケアの口が要るため）
        static var preview: GoalSetupSession {
            GoalSetupSession(
                today: { .sampleToday },
                start: { _ in throw CancellationError() },
                makeFlow: { _ in preconditionFailure("プレビューでは流れを作らない") },
                answerLater: {}
            )
        }
    }
#endif
