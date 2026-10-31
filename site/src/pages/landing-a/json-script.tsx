import { raw } from "hono/html";

// 値を JSON にしてページに埋める。JSON の型の script は実行しないので、Content-Security-Policy の script-src に当たらない。
// 中の </script> でタグが閉じられないよう < を逃がす
export const JsonScript = ({
  type,
  value,
}: {
  type: "application/json" | "application/ld+json";
  value: unknown;
}) => <script type={type}>{raw(JSON.stringify(value).replaceAll("<", "\\u003c"))}</script>;
