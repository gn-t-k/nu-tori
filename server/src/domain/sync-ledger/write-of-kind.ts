import type { KindWrites } from "./kind-writes";
import type { WriteBase } from "./write-base";

// 登録簿の種類から、書き込みの型を導く
export type WriteOfKind<TKind> = TKind extends {
  writes: KindWrites<infer TWrite extends WriteBase> | undefined;
}
  ? TWrite
  : never;
