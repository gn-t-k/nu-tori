import Foundation

/// 入力欄の「写真」を押したときの、写真の選び方
enum MealPhotoSelection {
    /// 標準の写真を選ぶ画面を出す
    case picker
    #if DEBUG
        /// 選ぶ画面を出さず、決まった写真を選んだことにして記録する。UI テストだけが使う
        /// （標準の選ぶ画面はアプリの外のプロセスで動き、`PhotosPickerItem` もテストから作れないため）。
        /// `pickedAt` は選び終えた時刻
        case fixed(record: (_ pickedAt: Date) async -> Void)
    #endif
}
