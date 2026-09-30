import type { CurrentRecord } from "./current-record";
import type { KindWrites } from "./kind-writes";
import type { WriteBase } from "./write-base";

// 記録の種類が帳簿に見せる入口。置き場は種類が閉じ込めて持つ
export type RecordKind<TName extends string, TWrite extends WriteBase, TValue> = {
  name: TName;
  // サーバーだけが書く種類は、端末からの書き込みを宣言しない
  writes: KindWrites<TWrite> | undefined;
  readCurrent(recordId: string): CurrentRecord<TValue>;
};
