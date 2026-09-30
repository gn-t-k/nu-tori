#if DEBUG
    import SwiftUI

    extension EnvironmentValues {
        /// UI テストでは Apple の画面を通さず、この結果をボタンが返す。実機とリリースのビルドでは nil
        @Entry var stubbedAppleSignInResult: AppleSignInResult?
    }
#endif
