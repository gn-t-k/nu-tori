/// 入力欄の「写真」で、選ぶ画面を開かずに選んだことにする写真
struct UITestPickedPhotos {
    let count: Int
    /// 読み終えるまでにかける秒数。読んでいるあいだの仮のカードを確かめるときだけ延ばす
    var loadingSeconds: Double = 0
    /// 選んだことにする写真のファイル（Mac のパス）。nil なら写真ごとに色を変えた無地の写真にする
    var files: [String]?
}
