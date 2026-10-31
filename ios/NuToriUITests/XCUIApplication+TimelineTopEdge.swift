import XCTest

extension XCUIApplication {
    /// タイムラインの上の端（1日の丸の帯の下の線）で半分隠れている文字・ボタン・画像。無ければ空。
    /// 帯の下に流れていく行が、帯の線をまたいで切れて写るのを見つけるため。帯が無い画面（潜った画面）では空
    @MainActor func elementsClippedAtTimelineTop() throws -> [String] {
        let strip = descendants(matching: .any)["day-ring-strip"]
        let timeline = descendants(matching: .any)["timeline"]
        guard strip.exists, timeline.exists else { return [] }
        let edge = strip.frame.maxY
        // 1つずつ frame を聞くと要素ごとに問い合わせるので、木を1回で写してから見る
        return try Self.clipped(in: timeline.snapshot(), at: edge)
    }

    private static let leafTypes: Set<XCUIElement.ElementType> = [.staticText, .button, .image]

    /// 線より上に 1pt を超えて出て、線より下にも 1pt を超えて出ているもの
    private static func clipped(in snapshot: any XCUIElementSnapshot, at edge: CGFloat) -> [String]
    {
        let frame = snapshot.frame
        let own =
            leafTypes.contains(snapshot.elementType) && frame.minY < edge - 1
                && frame.maxY > edge + 1
            ? [
                "\(snapshot.identifier.isEmpty ? "-" : snapshot.identifier)「\(snapshot.label)」が上へ \(Int(edge - frame.minY))pt 隠れている（高さ \(Int(frame.height))pt）"
            ]
            : []
        return own + snapshot.children.flatMap { clipped(in: $0, at: edge) }
    }
}
