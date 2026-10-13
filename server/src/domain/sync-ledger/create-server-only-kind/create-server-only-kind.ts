import type { RecordId } from "../../record-id";
import type { KindFollows, RecordKind } from "../record-kind";

// サーバーだけが書く種類を作る。端末からの書き込みを宣言せず、今の値は find から作る（値が無ければ、無いと返す）。
// 親の記録と一緒に消える種類（記録の ID が親の ID の、推定の状態など）は、whenGone を deletion_mark にして親を渡す。
// 親が無ければ値を探さず、親の削除の印があれば削除の印を、無ければ無いと返す。削除の印を自分では持たないので、ほかに deletion_mark の形は無い
export const createServerOnlyKind = <
  TName extends string,
  TValue,
  TSourceName extends string = never,
>(
  kind: {
    name: TName;
    // ほかの種類の記録から計算する種類だけが渡す
    follows?: KindFollows<TSourceName>;
    find: (recordId: RecordId) => TValue | undefined;
  } & (
    | { whenGone: "never" | "absence" }
    | {
        whenGone: "deletion_mark";
        parent: {
          exists: (recordId: RecordId) => boolean;
          hasDeletion: (recordId: RecordId) => boolean;
        };
      }
  ),
): RecordKind<TName, never, TValue, never, TSourceName> => ({
  name: kind.name,
  writes: undefined,
  follows: kind.follows,
  whenGone: kind.whenGone,
  readCurrent: (recordId) => {
    if (kind.whenGone === "deletion_mark" && !kind.parent.exists(recordId)) {
      return kind.parent.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
    }
    const value = kind.find(recordId);
    return value === undefined ? { status: "absent" } : { status: "value", value };
  },
});
