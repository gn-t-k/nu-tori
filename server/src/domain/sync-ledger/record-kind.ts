import type { RecordId } from "../record-id";
import type { CurrentRecord } from "./current-record";
import type { RecordChangeTarget } from "./record-change-target";
import type { WriteReceiptId } from "./sync-ledger";
import type { WriteBase } from "./write-base";
import type { WriteKind } from "./write-kind";
import type { RejectionReason } from "../rejection-reason";
import type { UsageEvent } from "../usage-event";

// 記録の種類が帳簿に見せる入口。置き場は種類が閉じ込めて持つ
// TAddedName は、書き込みが変更を足せるほかの種類の名前。TSourceName は、計算の元にするほかの種類の名前。帳簿は登録簿にある種類だけを受け取る
export type RecordKind<
  TName extends string,
  TWrite extends WriteBase,
  TValue,
  TAddedName extends string = never,
  TSourceName extends string = never,
> = {
  name: TName;
  // サーバーだけが書く種類は、端末からの書き込みを宣言しない
  writes: KindWrites<TWrite, TAddedName> | undefined;
  // ほかの種類の記録から計算する種類だけが宣言する
  follows: KindFollows<TSourceName> | undefined;
  readCurrent(recordId: RecordId): CurrentRecord<TValue>;
  whenGone: WhenGone;
};

// 記録が消えたことを端末にどう届けるか。食い違う今の値を読んだら、帳簿が不具合として投げる（受け付けなかった書き込みの記録が無いのは除く。まだ作られていないことがあるため）
// - deletion_mark: 削除の印を残して届ける
// - absence: 削除の印を持たず、記録が無くなったこと（absent）を変更として届ける。ほかの記録から計算する種類（体重の傾向）
// - never: 記録は消えない。変更の並びが指す記録が無いのも、削除の印も不具合
export type WhenGone = "deletion_mark" | "absence" | "never";

// 端末からの書き込みを受ける種類が宣言するもの。メソッドの書き方は、登録簿の配列に型の違う種類を並べるため（引数を双変にする）
export type KindWrites<TWrite extends WriteBase, TAddedName extends string = never> = {
  isWrite(write: WriteBase): write is TWrite;
  // 受け付けるかを決める。読むだけで、書かない
  decide(write: TWrite): WriteDecision<TAddedName>;
};

// ほかの種類の記録から計算する種類が宣言するもの。元の種類は、計算する種類を知らない
export type KindFollows<TSourceName extends string> = {
  source: TSourceName;
  // 帳簿が、元の種類の書き込みを当てて行を書いたあとに、同じトランザクションの中で呼ぶ。書いたあとの記録を読み、自分の行を書き、変えた記録の ID を返す。帳簿は、元の書き込みの変更のあとに、控えと結ばずに並びに載せる
  afterSourceApplied: (receiptId: WriteReceiptId) => readonly RecordId[];
};

// 書き込みを受け付けるかの決定。控えに載せる結果、変更の並びに書き込みの記録を載せ直すか、後に続く種類を走らせるかは、
// 帳簿が決定の種類から決める（種類は書かない）
// - applied: 当てる。書き込みの記録の変更を控えと結んで載せ、後に続く種類を走らせる
// - unchanged: 今の値と同じなので何も書かない。控えは applied にするが、変更を載せず、後に続く種類も走らせない
// - ignored_duplicate: 同じ記録がもうあるので捨てる
// - ignored_tombstone: 削除の印のある記録への書き込みを捨てる。削除の印を取り終えた端末にも、作り直した記録を残させないよう、
//   書き込みの記録の変更を載せ直す
// - kept_corrected: 直してある記録なので、元のサンプルが消えても残す
// - rejected: 受け付けない
export type WriteDecision<TAddedName extends string = never> =
  | {
      result: "applied";
      writeKind: WriteKind;
      // 書き込みの控えと、変更の並びに載せる記録の ID
      recordId: RecordId;
      // 書き込みが直接変えた記録の外で、commit が変える記録。控えと結ばずに、書き込みの記録の変更のあとに、並びの順で載せる
      addedChanges: readonly RecordChangeTarget<TAddedName>[];
      // 書き込みを当てたときに、分析用に送る出来事。同じ書き込みの ID が再び届いたときは送らない
      usageEvents: readonly UsageEvent[];
      // 帳簿が控えを書いたあとに呼ぶ。控えの ID は帳簿しか作れないので、控えより先に自分の行を書けない。
      // addChange で足した変更は、addedChanges のあとに足した順で載せる。帳簿は、同じ記録の変更を最初の1つにまとめる
      commit: (
        receiptId: WriteReceiptId,
        addChange: (change: RecordChangeTarget<TAddedName>) => void,
      ) => void;
    }
  | {
      result: "unchanged" | "ignored_duplicate" | "kept_corrected";
      writeKind: WriteKind;
      recordId: RecordId;
    }
  | {
      result: "ignored_tombstone";
      writeKind: WriteKind;
      recordId: RecordId;
      // 捨てるときにも書く行（あとから届く書き込みを止める削除の印など）があるときだけ渡す
      commit?: (receiptId: WriteReceiptId) => void;
    }
  | {
      result: "rejected";
      writeKind: WriteKind;
      recordId: RecordId;
      reason: RejectionReason;
      // 受け付けないときにも書く行があるときだけ渡す
      commit?: (receiptId: WriteReceiptId) => void;
    };
