import Foundation
import OpenAPIRuntime

/// 対処した失敗の原因のエラーを、Sentry で見分けるためのドメインとコード。
/// エラーの文章と `userInfo` は持たない。記録の中身が混ざることがあるため
public struct FailureCause: Sendable, Equatable {
    public let domain: String
    public let code: Int

    public init(_ error: any Error) {
        // 生成したクライアントは、どの失敗も ClientError に包むので、包まれた原因を見る
        let cause: any Error =
            switch error {
            case let error as ClientError: error.underlyingError
            default: error
            }
        let bridged = cause as NSError
        domain = bridged.domain
        code = bridged.code
    }
}
