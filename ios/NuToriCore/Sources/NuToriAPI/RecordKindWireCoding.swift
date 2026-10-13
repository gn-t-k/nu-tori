import Foundation

/// 記録の種類1つの、線上の形との行き来。種類ごとに1つ書き、`RecordKindWireCodings` の表に足す
protocol RecordKindWireCoding: Sendable {
    var kind: Components.Schemas.RecordKindName { get }

    /// 端末が送る書き込みの行き来。サーバーだけが書く種類は nil
    var writes: (any RecordKindWriteWireCoding)? { get }

    /// 取りに行く変更を読む。この種類に無い形と、読めない中身は nil
    func change(_ form: SyncChange.WireForm, recordId: String, record: some Encodable)
        -> SyncChange?

    #if DEBUG
        /// 偽の同期サーバーが置いて返す、変更の線上の形。自分の変更でなければ nil
        func wire(of change: SyncChange) -> SyncChange.Wire?
    #endif
}

extension SyncChange {
    /// 線上の kind は、記録の種類の名前に、形ごとの接尾辞を付けたもの
    enum WireForm: CaseIterable {
        case value
        case deletion
        /// アカウントに1つの記録（体重の傾向）が無いこと
        case absence

        var kindSuffix: String {
            switch self {
            case .value: ""
            case .deletion: "_deletion"
            case .absence: "_absence"
            }
        }
    }
}

extension Encodable {
    /// 生成した型の record（中身を決めない入れ物）を、種類ごとの中身の形に読み直す
    func decoded<Payload: Decodable>(as payload: Payload.Type) throws -> Payload {
        try JSONDecoder().decode(payload, from: JSONEncoder().encode(self))
    }
}

extension Date {
    var millisecondsSince1970: Int {
        Int((timeIntervalSince1970 * 1000).rounded())
    }

    init(millisecondsSince1970 milliseconds: Int) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

#if DEBUG
    extension SyncChange {
        struct Wire {
            /// nil は、サーバーが返さない端末だけの変更（キャッシュからの取り除き）
            let form: WireForm?
            let recordId: String
            /// 値でない形は空の record
            let record: any Encodable

            static func value(id: UUID, record: some Encodable) -> Wire {
                Wire(form: .value, recordId: id.canonicalString, record: record)
            }

            static func deletion(id: UUID) -> Wire {
                Wire(form: .deletion, recordId: id.canonicalString, record: [String: String]())
            }

            static func deviceOnlyRemoval(id: UUID) -> Wire {
                Wire(form: nil, recordId: id.canonicalString, record: [String: String]())
            }
        }
    }
#endif
