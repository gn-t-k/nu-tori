import Foundation
import NuToriAPI
import OpenAPIRuntime

public enum HandledFailure: Sendable, Equatable, CaseIterable {
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
    /// 目標の設定の要求（下見・目標案・自分で決める目標体重・目標を決める）が失敗したか、サーバーが断った
    case goalSetupRequest
    /// 「購入を復元」で App Store と取引を突き合わせられなかった（`AppStore.sync()`）
    case appStoreSync

    /// 送るときの名前。Sentry の課題の題と fingerprint に使い、過去の報告と突き合わせるので変えない
    public var reportName: String {
        switch self {
        case .sync: "sync"
        case .healthRead: "health_read"
        case .healthWrite: "health_write"
        case .healthNutritionWrite: "health_nutrition_write"
        case .cacheSave: "cache_save"
        case .storeRecovery: "store_recovery"
        case .photoUpload: "photo_upload"
        case .reminderSchedule: "reminder_schedule"
        case .cacheRead: "cache_read"
        case .notificationPermissionRequest: "notification_permission_request"
        case .goalSetupRequest: "goal_setup_request"
        case .appStoreSync: "app_store_sync"
        }
    }

    /// 取り消し（タスクの取り消しと通信の取り消し）、つながらない・時間切れ、締め出し（426）、ロック中のヘルスケア（想定した結果）は送らない
    public static func reported(_ error: any Error, as area: HandledFailure) -> HandledFailure? {
        if error is CancellationError || error.isCancelledTransfer || error.isUnreachableOrTimedOut
            || error.isAppBuildUnsupported || error.isHealthDataLocked
        {
            return nil
        }
        return area
    }
}

extension Error {
    /// 取り消した通信。アプリが取り消したときと、App スイッチャーで閉じたときや裏にいるあいだにシステムが取り消したとき
    var isCancelledTransfer: Bool {
        switch self {
        case let error as ClientError:
            return error.underlyingError.isCancelledTransfer
        case let error as URLError:
            return error.code == .cancelled
        // swiftlint:disable:next no_default_in_switch - エラーは型が開いていて、見分けないものが来る
        default:
            return false
        }
    }

    /// 端末のロック中はヘルスケアのデータが暗号化されていて、読み書きが `HKError.errorDatabaseInaccessible` で失敗する。
    /// バックグラウンド配信でロック中に起こされると起き、アンカーを進めないので、次に起こされたときか開いたときに取り込む。
    /// NuToriCore は HealthKit を import しないので、ドメインとコードで見分ける
    var isHealthDataLocked: Bool {
        let error = self as NSError
        return error.domain == "com.apple.healthkit" && error.code == 6
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
        // swiftlint:disable:next no_default_in_switch - エラーは型が開いていて、見分けないものが来る
        default:
            return false
        }
    }
}
