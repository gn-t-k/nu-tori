#if DEBUG
    import SwiftUI

    #Preview("状態ごと", arguments: AppLockoutScreen.Sample.allCases) { sample in
        AppLockoutScreen(isOpening: sample.isOpening, openUpdate: {})
    }

    extension AppLockoutScreen {
        fileprivate enum Sample: CaseIterable {
            /// 押す前
            case idle
            /// 押して、更新する場所を開くのを待っている
            case opening

            var isOpening: Bool {
                switch self {
                case .idle: false
                case .opening: true
                }
            }
        }
    }
#endif
