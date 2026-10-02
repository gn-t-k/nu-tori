import { getMigrations } from "better-auth/db/migration";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { createAuthenticationOptions } from "./index";

// Better Auth の版を上げて中核の表が変わったら、ここで落ちる（docs/agents/dependencies.md「npm の依存ごとの注意」）
describe("Better Auth の設定", () => {
  describe("移行を当てた D1 があるとき", () => {
    let migrations: Awaited<ReturnType<typeof getMigrations>>;
    beforeEach(async () => {
      migrations = await getMigrations(createAuthenticationOptions(env, "https://example.com"), {
        throwOnUnsafe: false,
      });
    });

    test("足りない表が無いこと", () => {
      expect(migrations.toBeCreated).toEqual([]);
    });

    test("足りない列が無いこと", () => {
      expect(migrations.toBeAdded).toEqual([]);
    });

    test("足りない索引が無いこと", () => {
      expect(migrations.toBeAddedIndexes).toEqual([]);
    });

    test("足すと危ない変更が無いこと", () => {
      expect(migrations.unsafeChanges).toEqual([]);
    });

    test("表の形の食い違いが無いこと", () => {
      expect(migrations.schemaProblems).toEqual([]);
    });
  });
});
