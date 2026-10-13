import Foundation

/// 端末が書く記録の種類1つの、書き込みの線上の形との行き来
protocol RecordKindWriteWireCoding: RecordKindWireCoding {
    /// 送る書き込みの線上の形と、当たる記録の ID。自分の書き込みでなければ nil
    func wire(of write: SyncWrite) -> SyncWrite.Wire?

    #if DEBUG
        /// 偽の同期サーバーとテストが、送られた書き込みを送る前の型に戻す。自分の書き込みでなければ nil、形の合わない値は投げる
        func sentWrite(_ wire: Components.Schemas.SyncWrite) throws -> SyncWrite?
    #endif
}

extension SyncWrite {
    struct Wire {
        let recordId: UUID
        let body: Components.Schemas.SyncWrite
    }
}

#if DEBUG
    /// 送られた書き込みを読むときの、値の読み方
    extension RecordKindWriteWireCoding {
        func uuid(_ value: String) throws -> UUID {
            try SentSyncWrites.uuid(value)
        }

        func knownTimeZone(_ identifier: String) throws -> TimeZone {
            try SentSyncWrites.knownTimeZone(identifier)
        }
    }
#endif
