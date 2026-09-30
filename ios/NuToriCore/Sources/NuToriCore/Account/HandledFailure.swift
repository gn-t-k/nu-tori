import Foundation
import OpenAPIRuntime

public enum HandledFailure: Sendable, Equatable {
    case sync
    case healthRead
    case healthWrite
    case cacheSave
    /// 端末の置き場を開けず、送り待ちを捨てたか、退避して作り直した
    case storeRecovery

    public static func reported(_ error: any Error, as area: HandledFailure) -> HandledFailure? {
        if error is CancellationError || error.isUnreachableOrTimedOut {
            return nil
        }
        return area
    }
}

extension Error {
    var isUnreachableOrTimedOut: Bool {
        let unreachableOrTimedOutCodes: Set<URLError.Code> = [
            .notConnectedToInternet, .timedOut, .networkConnectionLost,
            .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
            .dataNotAllowed, .internationalRoamingOff, .callIsActive,
        ]
        switch self {
        case let error as ClientError:
            return error.underlyingError.isUnreachableOrTimedOut
        case let error as URLError:
            return unreachableOrTimedOutCodes.contains(error.code)
        default:
            return false
        }
    }
}
