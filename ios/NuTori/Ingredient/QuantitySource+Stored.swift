import NuToriCore

/// キャッシュの料理と材料が持つ、量の出どころの文字列（サーバーの `quantitySource` と同じ書き方）
extension QuantitySource {
    nonisolated init?(stored: String) {
        switch stored {
        case "estimated": self = .estimated
        case "corrected": self = .corrected
        default: return nil
        }
    }

    nonisolated var stored: String {
        switch self {
        case .estimated: "estimated"
        case .corrected: "corrected"
        }
    }
}
