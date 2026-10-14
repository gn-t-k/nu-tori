#if DEBUG
    import Foundation

    /// 偽の同期サーバーが、記録を置く鍵と、返す変更の線上の形を、種類の符号化の表から引く
    extension SyncChange {
        var recordKey: FakeSyncServer.RecordKey {
            .init(kind: wireCoding.kind, id: wire.recordId)
        }

        var isDeletion: Bool {
            wire.form != .value
        }

        fileprivate var wireKind: String {
            guard let form = wire.form else {
                preconditionFailure("サーバーは \(wireCoding.kind.rawValue) の取り除きを返さない")
            }
            return wireCoding.kind.rawValue + form.kindSuffix
        }

        /// 生成した型の record（中身を決めない入れ物）に、記録の中身の形を詰める
        fileprivate func recordPayload<Payload: Decodable>() throws -> Payload {
            try wire.record.decoded(as: Payload.self)
        }

        private var wire: Wire {
            guard let wire = wireCoding.wire(of: self) else {
                preconditionFailure("\(wireCoding.kind.rawValue) の適合が、この変更を線上の形にしない")
            }
            return wire
        }

        private var wireCoding: any RecordKindWireCoding {
            guard let recordKind else {
                preconditionFailure("知らない種類の記録は置けない")
            }
            return RecordKindWireCodings.coding(of: recordKind)
        }
    }

    extension FakeSyncServer.RecordKey {
        init(kind: Components.Schemas.RecordKindName, id: UUID) {
            self.init(kind: kind, id: id.canonicalString)
        }
    }

    extension Components.Schemas.SyncChange {
        init(_ change: SyncChange, sequence: Int) throws {
            self.init(
                sequence: sequence, kind: change.wireKind, recordId: change.recordKey.id,
                record: try change.recordPayload())
        }
    }

    extension Components.Schemas.GoalDecisionChange {
        init(_ change: SyncChange) throws {
            self.init(
                kind: change.wireKind, recordId: change.recordKey.id,
                record: try change.recordPayload())
        }
    }

    extension Components.Schemas.SyncWriteCurrent.ChangePayload {
        init(_ change: SyncChange) throws {
            self.init(
                kind: change.wireKind, recordId: change.recordKey.id,
                record: try change.recordPayload())
        }
    }

    extension SyncWriteResult.Current {
        /// 断った書き込みに添える `current` の JSON。テストのトランスポートが、偽の同期サーバーと同じ形で返すため
        public func json() throws -> String {
            String(
                decoding: try JSONEncoder().encode(Components.Schemas.SyncWriteCurrent(self)),
                as: UTF8.self)
        }
    }

    extension Components.Schemas.SyncWriteCurrent {
        init(_ current: SyncWriteResult.Current) throws {
            switch current {
            case .value(let change):
                self.init(status: "value", change: try .init(change))
            case .deleted(let change):
                self.init(status: "deleted", change: try .init(change))
            case .absent:
                self.init(status: "absent")
            }
        }
    }
#endif
