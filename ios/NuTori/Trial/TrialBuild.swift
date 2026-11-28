import NuToriCore

/// 試作の切り替えを出す版か。TestFlight の版でだけ出す（docs/agents/decisions.md の「アプリの見た目と動きを実機で比べる試作」）。
/// 試作が無いあいだも、このファイルは残す
enum TrialBuild {
    /// デバッグビルドは TestFlight と見分けられず出さないので、UI テストと見本の撮影には切り替えが写らない
    static func showsSwitches() async -> Bool {
        await AppUpdateDestination.forThisInstall() == .testFlight
    }
}
