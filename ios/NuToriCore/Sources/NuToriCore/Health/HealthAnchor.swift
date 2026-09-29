public import Foundation

/// ヘルスケアの問い合わせの続きを指す印。中身は、ヘルスケアに触れる層だけが読む
public struct HealthAnchor: Sendable, Equatable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}
