/// 触覚を鳴らすときごとの型。選び直していないときは本番の型（`HapticMoment.standard`）を返す。
/// 選び直すのは「動きの見本」だけで、本番はいつも `standard` を使う
public struct HapticTrial: Equatable, Sendable {
    /// どのときも本番の型
    public static let standard = HapticTrial()

    public subscript(moment: HapticMoment) -> HapticChoice {
        get { chosen[moment] ?? moment.standard }
        // 本番の型に選び直したら持たない。全部を本番の型に戻したものが `standard` と等しくなる
        set { chosen[moment] = newValue == moment.standard ? nil : newValue }
    }

    private var chosen: [HapticMoment: HapticChoice] = [:]
}
