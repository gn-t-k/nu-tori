import OpenAPIRuntime

/// サーバーが 426 を返した。どの操作でも、応答の解釈より前に投げる
public struct AppBuildUnsupportedError: Error, Equatable {}

extension Error {
    /// 締め出しのエラーか。生成したクライアントは、ミドルウェアが投げたエラーを `ClientError` に包むので、中も見る
    public var isAppBuildUnsupported: Bool {
        switch self {
        case is AppBuildUnsupportedError:
            return true
        case let error as ClientError:
            return error.underlyingError.isAppBuildUnsupported
        default:
            return false
        }
    }
}
