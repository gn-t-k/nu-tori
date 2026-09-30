import Foundation
import NuToriAPI

extension APIEnvironment {
    /// デバッグビルドは開発用に、TestFlight と App Store の版は本番につなぐ
    static var forThisBuild: APIEnvironment {
        #if DEBUG
            .development
        #else
            .production
        #endif
    }
}
