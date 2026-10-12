#if DEBUG
    public import Foundation

    /// `POST /v1/sync/writes` で端末が送った本文を、送る前の型に戻したもの。偽の同期サーバーとテストが読む
    ///
    /// 生成した型で読むので、線上の名前をここに書かない。知らない種類の書き込みや、形の合わない値を読んだら投げる
    public struct SentSyncWrites: Sendable, Equatable {
        public let clientState: SyncClientState
        public let isFinalBatch: Bool
        public let writes: [SyncWrite]

        public init(json: Data) throws {
            let payload = try JSONDecoder().decode(
                Operations.PushSyncWrites.Input.Body.JsonPayload.self, from: json)
            clientState = try SyncClientState(payload.clientState)
            isFinalBatch = payload.isFinalBatch
            writes = try payload.writes.map(SyncWrite.init)
        }

        /// UUID としては読めるが、小文字の正規形でない ID。本物のサーバーは要求ごと 400 で断る
        public struct NonCanonicalIdError: Error {
            public let value: String
        }

        public struct MalformedBodyError: Error {
            public let reason: String
        }
    }

    extension SyncClientState {
        fileprivate init(
            _ state: Operations.PushSyncWrites.Input.Body.JsonPayload.ClientStatePayload
        ) throws {
            self.init(
                deviceId: try SentSyncWrites.uuid(state.deviceId),
                timeZone: try SentSyncWrites.knownTimeZone(state.timeZone),
                appVersion: state.appVersion,
                osVersion: state.osVersion,
                pendingWriteCount: state.pendingWriteCount,
                oldestPendingWriteAge: state.oldestPendingWriteAgeSeconds.map { .seconds($0) },
                pendingPhotoCount: state.pendingPhotoCount
            )
        }
    }

    extension SyncWrite {
        public var writeId: UUID {
            switch self {
            case .createWeightRecord(let writeId, _), .updateWeightRecord(let writeId, _),
                .sourceDeletedWeightRecord(let writeId, _), .updateAccountSettings(let writeId, _),
                .createMeal(let writeId, _), .updateMeal(let writeId, _, _),
                .deleteMeal(let writeId, _),
                .createDish(let writeId, _), .deleteDish(let writeId, _),
                .updateDish(let writeId, _),
                .updateIngredient(let writeId, _, _),
                .createNotice(let writeId, _), .respondNotice(let writeId, _, _),
                .createSentText(let writeId, _), .resendSentTextAsConversation(let writeId, _),
                .resendSentText(let writeId, _):
                writeId
            }
        }

        /// どの種類の書き込みかは、種類の符号化の表に順に尋ねて決める
        fileprivate init(_ write: Components.Schemas.SyncWrite) throws {
            for coding in RecordKindWireCodings.all {
                if let sent = try coding.writes?.sentWrite(write) {
                    self = sent
                    return
                }
            }
            throw SentSyncWrites.MalformedBodyError(reason: "どの種類の適合も読まない書き込み")
        }
    }

    extension SentSyncWrites {
        /// サーバーと同じく、小文字の正規形の文字列だけを UUID として読む
        static func uuid(_ value: String) throws -> UUID {
            if let uuid = UUID(canonicalString: value) {
                return uuid
            }
            guard UUID(uuidString: value) != nil else {
                throw MalformedBodyError(reason: "UUID でない \(value)")
            }
            throw NonCanonicalIdError(value: value)
        }

        static func knownTimeZone(_ identifier: String) throws -> TimeZone {
            guard let timeZone = TimeZone(identifier: identifier) else {
                throw MalformedBodyError(reason: "知らないタイムゾーン \(identifier)")
            }
            return timeZone
        }
    }
#endif
