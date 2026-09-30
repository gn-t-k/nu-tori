import Foundation
import OpenAPIRuntime

public enum HandledFailure: Sendable, Equatable {
    case sync
    case healthRead
    case healthWrite
    case cacheSave

    public static func reported(_ error: any Error, as area: HandledFailure) -> HandledFailure? {
        if error is CancellationError || error.isUnreachableOrTimedOut {
            return nil
        }
        return area
    }
}

extension Error {
    var isUnreachableOrTimedOut: Bool {
        switch self {
        case let error as ClientError:
            error.underlyingError.isUnreachableOrTimedOut
        case let error as URLError:
            unreachableOrTimedOutCodes.contains(error.code)
        default:
            false
        }
    }
}

private let unreachableOrTimedOutCodes: Set<URLError.Code> = [
    .notConnectedToInternet, .timedOut, .networkConnectionLost,
    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
    .dataNotAllowed, .internationalRoamingOff, .callIsActive,
]
