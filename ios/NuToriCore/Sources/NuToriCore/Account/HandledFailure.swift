import Foundation
import NuToriAPI
import OpenAPIRuntime

public enum HandledFailure: Sendable, Equatable {
    case sync
    case healthRead
    case healthWrite
    /// 栄養をヘルスケアに書く・消すことに失敗した
    case healthNutritionWrite
    case cacheSave
    /// 端末の置き場を開けず、送り待ちを捨てたか、退避して作り直した
    case storeRecovery
    /// 写真の縮小版を送れなかった
    case photoUpload
    /// 記録忘れの通知を予約できなかった
    case reminderSchedule
    /// キャッシュを読めなかった
    case cacheRead
    /// 通知の許可を求められなかった
    case notificationPermissionRequest

    /// 取り消し、つながらない・時間切れ、締め出し（426。想定した結果）は送らない
    public static func reported(_ error: any Error, as area: HandledFailure) -> HandledFailure? {
        if error is CancellationError || error.isUnreachableOrTimedOut
            || error.isAppBuildUnsupported
        {
            return nil
        }
        return area
    }
}

extension Error {
    /// 取り消した送信。アプリが取り消したときと、App スイッチャーで閉じてシステムが取り消したとき
    var isCancelledTransfer: Bool {
        switch self {
        case let error as URLError:
            return error.code == .cancelled
        default:
            return false
        }
    }

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
