// 構造化出力の JSON のできた分から、本文（先頭の body の文字列）のできた分を読む。
// JSON が body から始まっていなければ undefined を返す（そのときは、読み終えてから本文をまとめて渡す）。
// 途中で切れたエスケープと、対の片方だけのサロゲートは、続きが届くまで読まない（渡した分が本文の先頭とずれないように）
export const readStreamedReplyBody = (json: string): string | undefined => {
  const opening = /^\s*\{\s*"body"\s*:\s*"/.exec(json);
  if (opening === null) {
    return undefined;
  }
  const decoded = decodeStringPrefix(json.slice(opening[0].length));
  const last = decoded.charCodeAt(decoded.length - 1);
  return last >= 0xd800 && last <= 0xdbff ? decoded.slice(0, -1) : decoded;
};

// JSON の文字列の中身を、閉じる引用符か、読める終わりまで読む
const decodeStringPrefix = (raw: string): string => {
  let decoded = "";
  let index = 0;
  while (index < raw.length) {
    const char = raw.charAt(index);
    if (char === '"') {
      return decoded;
    }
    if (char !== "\\") {
      decoded += char;
      index += 1;
      continue;
    }
    const escaped = raw.charAt(index + 1);
    if (escaped === "u") {
      const hex = raw.slice(index + 2, index + 6);
      if (!/^[\da-fA-F]{4}$/.test(hex)) {
        return decoded;
      }
      decoded += String.fromCharCode(Number.parseInt(hex, 16));
      index += 6;
      continue;
    }
    const unescaped = simpleEscapes[escaped];
    if (unescaped === undefined) {
      return decoded;
    }
    decoded += unescaped;
    index += 2;
  }
  return decoded;
};

const simpleEscapes: Readonly<Record<string, string>> = {
  '"': '"',
  "\\": "\\",
  "/": "/",
  b: "\b",
  f: "\f",
  n: "\n",
  r: "\r",
  t: "\t",
};
