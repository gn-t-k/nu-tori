public enum HealthAuthorizationRequestStatus: Sendable, Equatable {
    /// この端末では、まだ許可を求めていない
    case notYetRequested
    case alreadyRequested
}
