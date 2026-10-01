// テストが設定ファイルを文字列として読む（import ... from "...?raw"）
declare module "*?raw" {
  const content: string;
  export default content;
}
