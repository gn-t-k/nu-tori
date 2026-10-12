import SwiftData

extension ModelContext {
    /// その型の行を、保存の前に足した行も含めてすべて消す。
    /// `delete(model:)` は、保存の前に足した行を残す。残すと、次の保存で置き場に書かれるので、あとから消す
    nonisolated func deleteAll<Row: PersistentModel>(_ model: Row.Type) throws {
        try delete(model: model)
        for row in try fetch(FetchDescriptor<Row>()) {
            delete(row)
        }
    }
}
