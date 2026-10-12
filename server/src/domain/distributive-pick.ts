// ユニオンの場合ごとに Pick する（Pick は、ユニオンのどの場合にもあるキーしか選べない）。その場合に無いキーは飛ばす
export type DistributivePick<TUnion, TKey extends PropertyKey> = TUnion extends unknown
  ? Pick<TUnion, Extract<keyof TUnion, TKey>>
  : never;
