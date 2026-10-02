import { describe, expect, test } from "vitest";
import testCases from "../../../../../shared/daily-representative-weight.test-cases.json";
import { computeDailyRepresentativeWeights } from "./index";

describe("日の代表値", () => {
  test.for(testCases)(
    "$name とき、日ごとに実際の時刻でいちばん早い記録を、日の順に返すこと",
    ({ weightRecords, representativeWeights }) => {
      const representatives = computeDailyRepresentativeWeights(
        weightRecords.map((record) => ({ ...record, measuredAt: new Date(record.measuredAt) })),
      );

      expect(
        representatives.map(({ calendarDay, weightRecord }) => ({
          calendarDay,
          weightRecordId: weightRecord.id,
          weightKg: weightRecord.weightKg,
        })),
      ).toEqual(representativeWeights);
    },
  );
});
