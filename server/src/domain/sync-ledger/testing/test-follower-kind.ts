import type { CurrentRecord } from "../current-record";
import type { RecordKind } from "../record-kind";

export const testFollowerRecordId = "test_follower";

// 帳簿のテスト用の、テスト用の記録から計算する種類。元の書き込みを当てた回数を値に持つ
export const createTestFollowerKind = (
  operations: string[],
): RecordKind<"test_follower", never, number, never, "test_record"> => {
  let appliedCount = 0;
  return {
    name: "test_follower",
    writes: undefined,
    follows: {
      source: "test_record",
      afterSourceApplied: () => {
        operations.push("follower");
        appliedCount += 1;
        return [testFollowerRecordId];
      },
    },
    deliversAbsence: false,
    readCurrent: (recordId): CurrentRecord<number> =>
      recordId === testFollowerRecordId && appliedCount > 0
        ? { status: "value", value: appliedCount }
        : { status: "absent" },
  };
};
