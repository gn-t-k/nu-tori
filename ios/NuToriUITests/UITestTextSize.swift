/// UI テストで開くアプリの文字の大きさ。起動の値 `-UIPreferredContentSizeCategoryName` で渡し、端末の設定によらずこれにする
enum UITestTextSize: String {
    /// いちばん大きな文字（AX5）
    case accessibility5 = "UICTContentSizeCategoryAccessibilityXXXL"
}
