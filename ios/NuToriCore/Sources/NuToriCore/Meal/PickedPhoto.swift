public import Foundation

/// 選んだ写真1枚の、端末が振った ID と撮影時刻
public struct PickedPhoto: Hashable, Sendable {
    public let id: UUID
    public let takenTime: PhotoTakenTime

    public init(id: UUID, takenTime: PhotoTakenTime) {
        self.id = id
        self.takenTime = takenTime
    }
}
