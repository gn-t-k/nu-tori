/// 記録の種類の名前。送り待ち・変更・登録簿・「読める種類」がこれで種類を指す。
/// rawValue は送り待ちと同期の状態に保存する文字列なので、変えると置き場の移行が要る。
/// 種類を足すときは case を足し、`serverName` の switch にサーバーの列挙の名前を書く
public enum RecordKindName: String, Sendable, CaseIterable, Comparable {
    case accountSettings = "account-settings"
    case meal = "meal"
    case mealEstimationStatus = "meal-estimation-status"
    case weightRecord = "weight-record"

    /// サーバーの種類の名前の列挙（`server/openapi.json` の `RecordKindName`。snake_case）での書き方。
    /// 端末とサーバーの名前の対応はここだけに書く（サーバーの列挙との突き合わせはテストが行う）
    public var serverName: String {
        switch self {
        case .accountSettings: "account_settings"
        case .meal: "meal"
        case .mealEstimationStatus: "meal_estimation_status"
        case .weightRecord: "weight_record"
        }
    }

    public static func < (lhs: RecordKindName, rhs: RecordKindName) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
