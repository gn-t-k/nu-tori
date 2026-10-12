import type { RecordChangeWrites } from "./record-change-writes";

// 記録の変化を書く入口。受け口の要求やアラームが、端末の書き込みの外で記録を変えるときに通す（端末の書き込みは帳簿の push）。
// run の書き込みは1つのトランザクションに入り、変更には足した順に通し番号が付く。
// 推定と返事の流れの出来事で変わった状態の変更は、run が終わったあとに入口が足すので、run が足した変更よりあとに並ぶ
export type RecordChangeWriter = <T>(run: (writes: RecordChangeWrites) => T) => T;
