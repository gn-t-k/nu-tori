/// 入力欄の「写真」で、選ぶ画面を開かずに選んだことにする写真
struct UITestPickedPhotos {
    let source: Source
    /// 読み終えるまでにかける秒数。読んでいるあいだの仮のカードを確かめるときだけ延ばす
    var loadingSeconds: Double = 0

    /// 選んだことにする写真の出どころ
    enum Source {
        /// 写真ごとに色を変えた無地の写真を、この枚数
        case solidColors(count: Int)
        /// このファイルの写真（Mac のパス）
        case files([String])
    }
}
