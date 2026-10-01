import type { CurrentRecord } from "./current-record";
import type { WriteReceiptId } from "./sync-ledger";
import type { WriteBase } from "./write-base";
import type { WriteKind } from "./write-kind";
import type { SyncWriteOutcome } from "../sync-write-outcome";

// 記録の種類が帳簿に見せる入口。置き場は種類が閉じ込めて持つ
export type RecordKind<TName extends string, TWrite extends WriteBase, TValue> = {
  name: TName;
  // サーバーだけが書く種類は、端末からの書き込みを宣言しない
  writes: KindWrites<TWrite> | undefined;
  readCurrent(recordId: string): CurrentRecord<TValue>;
};

// 端末からの書き込みを受ける種類が宣言するもの。メソッドの書き方は、登録簿の配列に型の違う種類を並べるため（引数を双変にする）
export type KindWrites<TWrite extends WriteBase> = {
  isWrite(write: WriteBase): write is TWrite;
  // 受け付けるかを決める。読むだけで、書かない
  decide(write: TWrite): WriteDecision;
};

export type WriteDecision = {
  writeKind: WriteKind;
  // 書き込みの控えに載せる記録の ID
  recordId: string;
  outcome: SyncWriteOutcome;
  // 変更の並びに載せる記録の ID。載せないとき undefined
  changedRecordId: string | undefined;
  // 帳簿が控えを書いたあとに呼ぶ。控えの ID は帳簿しか作れないので、控えより先に自分の行を書けない
  commit: (receiptId: WriteReceiptId) => void;
};
