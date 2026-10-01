// 備考の「別名： あ、い」の行を別名の並びにする
export const readAliases = (remarks: unknown): string[] => {
  if (typeof remarks !== "string") {
    return [];
  }
  return remarks
    .split(/\r?\n/)
    .flatMap((line) => {
      const alias = /^別名[：:]\s*(.+)$/.exec(line);
      return alias?.[1] === undefined ? [] : alias[1].split("、");
    })
    .map((alias) => alias.trim())
    .filter((alias) => alias !== "");
};
