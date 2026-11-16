import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import type { LedgerStore } from "./sync-ledger/ledger-store";

// 直近 24 時間に控えを残した書き込み（受け付けなかったものを含む）の数で、同期の書き込みの要求を受けるかを決める。
// 上限に届くまでは、要求をまるごと受ける（1回の要求は 500 件までなので、超える幅も 500 件に満たない）。
// 要求の途中で断ると、端末が同じ 500 件を送り直しても通らない書き込みが残るため
export const ensureSyncWriteAllowance = (
  ledgerStore: Pick<LedgerStore<string>, "countWriteReceiptsAfter">,
  now: Date,
): R.Result<void, SyncWriteAllowanceExhaustedError> =>
  ledgerStore.countWriteReceiptsAfter(new Date(now.getTime() - allowanceWindowMilliseconds)) <
  maximumWritesPerWindow
    ? R.succeed()
    : R.fail(new SyncWriteAllowanceExhaustedError());

export class SyncWriteAllowanceExhaustedError extends ErrorFactory({
  name: "SyncWriteAllowanceExhaustedError",
  message: "直近 24 時間の書き込みの数が上限に届いている",
}) {}

const allowanceWindowMilliseconds = 24 * 60 * 60 * 1000;
// ふつうの使い方でいちばん多いのは、ヘルスケアにある体重を初めて取り込んだときの送信で、1日2回を 40 年量っても届かない数にする
const maximumWritesPerWindow = 30_000;
