public import Foundation

public enum APIEnvironment: Sendable {
    case development
    case production

    public var serverURL: URL {
        // ホスト名の正本は server/wrangler.jsonc の routes
        switch self {
        case .development: URL(string: "https://api-dev.nu-tori.app")!
        case .production: URL(string: "https://api.nu-tori.app")!
        }
    }
}
