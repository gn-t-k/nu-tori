import type { CurrentRecord } from "./current-record";
import type { RecordChangeTarget } from "./record-change-target";
import type { WriteReceiptId } from "./sync-ledger";
import type { WriteBase } from "./write-base";
import type { WriteKind } from "./write-kind";
import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { UsageEvent } from "../usage-event";

// 記録の種類が帳簿に見せる入口。置き場は種類が閉じ込めて持つ
// TAddedName は、書き込みが変更を足せるほかの種類の名前。帳簿は登録簿にある種類だけを受け取る
export type RecordKind<
  TName extends string,
  TWrite extends WriteBase,
  TValue,
  TAddedName extends string = never,
> = {
  name: TName;
  // サーバーだけが書く種類は、端末からの書き込みを宣言しない
  writes: KindWrites<TWrite, TAddedName> | undefined;
  readCurrent(recordId: string): CurrentRecord<TValue>;
};

// 端末からの書き込みを受ける種類が宣言するもの。メソッドの書き方は、登録簿の配列に型の違う種類を並べるため（引数を双変にする）
export type KindWrites<TWrite extends WriteBase, TAddedName extends string = never> = {
  isWrite(write: WriteBase): write is TWrite;
  // 受け付けるかを決める。読むだけで、書かない
  decide(write: TWrite): WriteDecision<TAddedName>;
};

export type WriteDecision<TAddedName extends string = never> = {
  writeKind: WriteKind;
  // 書き込みの控えに載せる記録の ID
  recordId: string;
  outcome: SyncWriteOutcome;
  // 変更の並びに載せる記録の ID。書き込みの控えと結ぶ。載せないとき undefined
  changedRecordId: string | undefined;
  // 書き込みが直接変えた記録の外で、commit が変える記録。控えと結ばずに、changedRecordId の変更のあとに、並びの順で載せる
  addedChanges: readonly RecordChangeTarget<TAddedName>[];
  // 書き込みを当てたときに、分析用に送る出来事。同じ書き込みの ID が再び届いたときは送らない
  usageEvents: readonly UsageEvent[];
  // 帳簿が控えを書いたあとに呼ぶ。控えの ID は帳簿しか作れないので、控えより先に自分の行を書けない
  commit: (receiptId: WriteReceiptId) => void;
};
