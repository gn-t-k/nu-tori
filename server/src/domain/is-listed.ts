// 区分の値が一覧にあるか。区分の列に CHECK は無いので、書く口が型をすり抜けた値を書く前に止めるのに使う
export const isListed = (values: readonly string[], value: string): boolean =>
  values.includes(value);
