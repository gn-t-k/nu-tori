/// 記録の種類の名前。送り待ち・変更・登録簿・「読める種類」がこれで種類を指す。
/// rawValue は送り待ちと同期の状態に保存する文字列なので、変えると置き場の移行が要る。
/// 種類を足すときは case を足し、`serverName` の switch にサーバーの列挙の名前を書く
public enum RecordKindName: String, Sendable, CaseIterable, Comparable {
    case accountSettings = "account-settings"
    case aiUtterance = "ai-utterance"
    case dish = "dish"
    case dishEstimationStatus = "dish-estimation-status"
    case ingredient = "ingredient"
    case meal = "meal"
    case mealEstimationStatus = "meal-estimation-status"
    case notice = "notice"
    case sentText = "sent-text"
    case sentTextStatus = "sent-text-status"
    case usualWeighingTime = "usual-weighing-time"
    case weightRecord = "weight-record"
    case weightTrend = "weight-trend"

    /// サーバーの種類の名前の列挙（`server/openapi.json` の `RecordKindName`。snake_case）での書き方。
    /// 端末とサーバーの名前の対応はここだけに書く（サーバーの列挙との突き合わせはテストが行う）
    public var serverName: String {
        switch self {
        case .accountSettings: "account_settings"
        case .aiUtterance: "ai_utterance"
        case .dish: "dish"
        case .dishEstimationStatus: "dish_estimation_status"
        case .ingredient: "ingredient"
        case .meal: "meal"
        case .mealEstimationStatus: "meal_estimation_status"
        case .notice: "notice"
        case .sentText: "sent_text"
        case .sentTextStatus: "sent_text_status"
        case .usualWeighingTime: "usual_weighing_time"
        case .weightRecord: "weight_record"
        case .weightTrend: "weight_trend"
        }
    }

    public static func < (lhs: RecordKindName, rhs: RecordKindName) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
