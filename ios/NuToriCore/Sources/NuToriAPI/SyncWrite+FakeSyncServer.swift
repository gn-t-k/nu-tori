#if DEBUG
    extension SyncWrite {
        /// 書き込みが当たる記録
        var recordKey: FakeSyncServer.RecordKey {
            guard let wire = try? wire() else {
                preconditionFailure("\(recordKind.rawValue) の適合が、この書き込みを線上の形にしない")
            }
            return .init(kind: recordKind, id: wire.recordId)
        }
    }
#endif
