import path from "node:path";

// 評価のスクリプトを置いた server/ の道
export const serverDirectory = path.resolve(import.meta.dirname, "..");
