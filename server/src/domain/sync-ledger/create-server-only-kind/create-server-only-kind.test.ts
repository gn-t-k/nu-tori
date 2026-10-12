import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../record-id";
import type { KindFollows } from "../record-kind";
import { createServerOnlyKind } from "./index";

const recordId = generateRecordId();

describe("サーバーだけが書く種類", () => {
  describe("消えない種類で", () => {
    let values: Map<RecordId, number>;
    let kind: ReturnType<typeof createServerOnlyKind<"test_status", number>>;
    beforeEach(() => {
      values = new Map();
      kind = createServerOnlyKind({
        name: "test_status",
        whenGone: "never",
        find: (id) => values.get(id),
      });
    });

    test("端末からの書き込みも、計算の元も宣言しないこと", () => {
      expect(kind).toMatchObject({
        name: "test_status",
        writes: undefined,
        follows: undefined,
        whenGone: "never",
      });
    });

    describe("値があるとき", () => {
      beforeEach(() => {
        values.set(recordId, 3);
      });

      test("その値を返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "value", value: 3 });
      });
    });

    describe("値が無いとき", () => {
      test("無いと返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "absent" });
      });
    });
  });

  describe("親の記録と一緒に消える種類で", () => {
    let parents: Set<RecordId>;
    let deletedParents: Set<RecordId>;
    let values: Map<RecordId, number>;
    let kind: ReturnType<typeof createServerOnlyKind<"test_status", number>>;
    beforeEach(() => {
      parents = new Set();
      deletedParents = new Set();
      values = new Map();
      kind = createServerOnlyKind({
        name: "test_status",
        whenGone: "deletion_mark",
        parent: {
          exists: (id) => parents.has(id),
          hasDeletion: (id) => deletedParents.has(id),
        },
        find: (id) => values.get(id),
      });
    });

    test("消えたことを削除の印で届けると宣言すること", () => {
      expect(kind.whenGone).toBe("deletion_mark");
    });

    describe("親があって値があるとき", () => {
      beforeEach(() => {
        parents.add(recordId);
        values.set(recordId, 3);
      });

      test("その値を返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "value", value: 3 });
      });
    });

    describe("親があって値が無いとき", () => {
      beforeEach(() => {
        parents.add(recordId);
      });

      test("無いと返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "absent" });
      });
    });

    describe("親が無く、親の削除の印があるとき", () => {
      beforeEach(() => {
        deletedParents.add(recordId);
        values.set(recordId, 3);
      });

      test("削除の印を返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "deleted" });
      });
    });

    describe("親も親の削除の印も無く、値だけがあるとき", () => {
      beforeEach(() => {
        values.set(recordId, 3);
      });

      test("値を探さずに無いと返すこと", () => {
        expect(kind.readCurrent(recordId)).toEqual({ status: "absent" });
      });
    });
  });

  describe("ほかの種類から計算する種類で", () => {
    let follows: KindFollows<"test_record">;
    let kind: ReturnType<typeof createServerOnlyKind<"test_follower", number, "test_record">>;
    beforeEach(() => {
      follows = { source: "test_record", afterSourceApplied: () => [recordId] };
      kind = createServerOnlyKind({
        name: "test_follower",
        whenGone: "absence",
        follows,
        find: (): number | undefined => undefined,
      });
    });

    test("計算の元をそのまま宣言すること", () => {
      expect(kind).toMatchObject({ follows, whenGone: "absence" });
    });
  });
});
