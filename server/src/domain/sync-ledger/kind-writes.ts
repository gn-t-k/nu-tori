import type { WriteBase } from "./write-base";
import type { WriteDecision } from "./write-decision";

// 端末からの書き込みを受ける種類が宣言するもの。メソッドの書き方は、登録簿の配列に型の違う種類を並べるため（引数を双変にする）
export type KindWrites<TWrite extends WriteBase> = {
  isWrite(write: WriteBase): write is TWrite;
  // 受け付けるかを決める。読むだけで、書かない
  decide(write: TWrite): WriteDecision;
};
