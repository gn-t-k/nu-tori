import Foundation

/// サーバーが同期する記録の種類の名前。`server/openapi.json` の `RecordKindName` の列挙から生成した値。
/// 端末の `RecordKindName` との対応は、`RecordKindName.serverName` の switch に書く
public enum ServerRecordKindNames {
    /// サーバーの書き方（snake_case）の名前
    public static var names: Set<String> {
        // #675 で端末の記録の種類として足すまでの手当て。端末がまだ扱わない種類は、突き合わせから外す
        Set(
            Components.Schemas.RecordKindName.allCases.filter { $0 != .subscriptionStatus }.map(
                \.rawValue))
    }
}
