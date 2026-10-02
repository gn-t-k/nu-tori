import { env } from "cloudflare:workers";
import { describe, expect, test } from "vitest";
import { app } from "../app";

describe("浅い確認の経路", () => {
  describe("D1 を読めるとき", () => {
    test("認証なしで呼ぶと、200 を返すこと", async () => {
      const response = await app.request("/health", {}, env);
      expect(response.status).toBe(200);
    });

    test("本文は決まった形だけで、記録の中身もアカウントの情報も入れないこと", async () => {
      const response = await app.request("/health", {}, env);
      expect(await response.json()).toEqual({ status: "ok" });
    });
  });
});
