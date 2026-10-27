import type { EstimationWrites } from "../estimation/domain/estimation-writes";
import type { ReplyWrites } from "../reply/domain/reply-writes";
import type { RecordType } from "./record-type";
import type { RecordChangeTarget } from "./sync-ledger/record-change-target";

// 記録の変化の書き込み。記録の変化を書く入口（RecordChangeWriter）が、書く関数にだけ渡す
export type RecordChangeWrites = {
  // 記録の行を置き場に書いたら、変えた記録をここに渡す
  addChange: (change: RecordChangeTarget<RecordType>) => void;
  // 推定の予定と結果を書く
  estimation: EstimationWrites;
  // 返事の流れの出来事を書く
  reply: ReplyWrites;
};
