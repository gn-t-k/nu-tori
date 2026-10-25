/// 入力欄の「写真」で、選ぶ画面を開かずに選んだことにする写真
struct UITestPickedPhotos {
    let count: Int
    /// 読み終えるまでにかける秒数。読んでいるあいだの仮のカードを確かめるときだけ延ばす
    var loadingSeconds: Double = 0
}
