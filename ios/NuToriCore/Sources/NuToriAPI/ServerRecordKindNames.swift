import Foundation

/// サーバーが同期する記録の種類の名前。`server/openapi.json` の `RecordKindName` の列挙から生成した値
public enum ServerRecordKindNames {
    /// サーバーの書き方（snake_case）の名前
    public static var names: Set<String> {
        Set(Components.Schemas.RecordKindName.allCases.map(\.rawValue))
    }

    /// 端末の登録簿の書き方（ハイフン）にした名前。
    /// 送り待ちに保存した名前（`weight-record` など）を変えると、送り待ちの置き場の移行が要るので、端末の名前は変えず、突き合わせるときにサーバーの名前を寄せる
    public static var deviceNames: Set<String> {
        Set(names.map { $0.replacingOccurrences(of: "_", with: "-") })
    }
}
