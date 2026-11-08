import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../record-id";
import { readStoredRecord } from "./index";

const recordId = generateRecordId();

describe("置き場から記録の今の値を読む", () => {
  describe("削除の印を持つ置き場で", () => {
    let values: Map<RecordId, number>;
    let deletions: Set<RecordId>;
    let store: Parameters<typeof readStoredRecord<number>>[0];
    beforeEach(() => {
      values = new Map();
      deletions = new Set();
      store = { find: (id) => values.get(id), hasDeletion: (id) => deletions.has(id) };
    });

    describe("値があるとき", () => {
      beforeEach(() => {
        values.set(recordId, 3);
      });

      test("その値を返すこと", () => {
        expect(readStoredRecord(store, recordId)).toEqual({ status: "value", value: 3 });
      });
    });

    describe("値が無く、削除の印があるとき", () => {
      beforeEach(() => {
        deletions.add(recordId);
      });

      test("削除の印を返すこと", () => {
        expect(readStoredRecord(store, recordId)).toEqual({ status: "deleted" });
      });
    });

    describe("値も削除の印も無いとき", () => {
      test("無いと返すこと", () => {
        expect(readStoredRecord(store, recordId)).toEqual({ status: "absent" });
      });
    });
  });

  describe("削除の印を持たない置き場で", () => {
    let values: Map<RecordId, number>;
    let store: Parameters<typeof readStoredRecord<number>>[0];
    beforeEach(() => {
      values = new Map();
      store = { find: (id) => values.get(id) };
    });

    describe("値があるとき", () => {
      beforeEach(() => {
        values.set(recordId, 3);
      });

      test("その値を返すこと", () => {
        expect(readStoredRecord(store, recordId)).toEqual({ status: "value", value: 3 });
      });
    });

    describe("値が無いとき", () => {
      test("無いと返すこと", () => {
        expect(readStoredRecord(store, recordId)).toEqual({ status: "absent" });
      });
    });
  });
});
