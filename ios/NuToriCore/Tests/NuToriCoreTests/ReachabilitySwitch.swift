/// 要求のあいだに、電波が切れた・戻ったことにする
final class ReachabilitySwitch: @unchecked Sendable {
    var isReachable: Bool

    init(isReachable: Bool) {
        self.isReachable = isReachable
    }
}
