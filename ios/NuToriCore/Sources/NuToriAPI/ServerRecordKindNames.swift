import Foundation

/// サーバーが同期する記録の種類の名前。`server/openapi.json` の `RecordKindName` の列挙から生成した値。
/// 端末の `RecordKindName` との対応は、`RecordKindName.serverName` の switch に書く
public enum ServerRecordKindNames {
    /// サーバーの書き方（snake_case）の名前
    public static var names: Set<String> {
        Set(Components.Schemas.RecordKindName.allCases.map(\.rawValue))
    }
}
