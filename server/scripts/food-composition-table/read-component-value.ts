// 成分表の本表のセルを数値に読む。値が無い（「-」・空のセル）ときは undefined（不明）で、0 にしない
export const readComponentValue = (cell: unknown): number | undefined => {
  // 「*」は、ヨウ素の値が本表に無く第3章を見るもの（3食品）。本表では不明
  if (cell === null || cell === undefined || cell === "-" || cell === "*") {
    return undefined;
  }
  if (typeof cell === "number") {
    return cell;
  }
  if (typeof cell !== "string") {
    throw new Error(`成分表のセルが数値でも文字列でもない（${typeof cell}）`);
  }
  // Tr は微量、(0) は推計の 0。どちらも 0 として扱う
  if (cell === "Tr" || cell === "(Tr)") {
    return 0;
  }
  // (11.3) は推計値、20.3† は規定法による測定値の印。どちらもその値
  const numeric = /^\(?([0-9]+(?:\.[0-9]+)?)\)?†?$/.exec(cell);
  if (numeric?.[1] === undefined) {
    throw new Error(`成分表のセルの知らない表記: ${cell}`);
  }
  return Number(numeric[1]);
};
