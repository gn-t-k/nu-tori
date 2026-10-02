import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { app } from "../app";
import { pullSyncChanges } from "../sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { setMinimumAppBuild, signInTestAccount } from "../testing";

describe("古いビルドの締め出し", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
  });

  describe("最低バージョンが 42 のとき", () => {
    beforeEach(() => {
      setMinimumAppBuild(42);
    });

    describe("ビルド番号が最低バージョンより小さいとき", () => {
      let response: Response;
      let logSpy: ReturnType<typeof vi.spyOn>;
      beforeEach(async () => {
        logSpy = vi.spyOn(console, "log");
        response = await pullSyncChanges(sessionToken, {}, { "x-app-build": "41" });
      });

      test("426 と決まった本文を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 426,
          body: { code: "app_build_unsupported" },
        });
      });

      test("要求ごとのログの1行に、ビルド番号を足すこと", () => {
        expect(logSpy).toHaveBeenCalledWith(expect.objectContaining({ status: 426, appBuild: 41 }));
      });
    });

    describe("ビルド番号が最低バージョンと等しいとき", () => {
      let response: Response;
      let logSpy: ReturnType<typeof vi.spyOn>;
      beforeEach(async () => {
        logSpy = vi.spyOn(console, "log");
        response = await pullSyncChanges(sessionToken, {}, { "x-app-build": "42" });
      });

      test("いつもどおり処理すること", () => {
        expect(response.status).toBe(200);
      });

      test("要求ごとのログの1行に、ビルド番号を足さないこと", () => {
        expect(logSpy).toHaveBeenCalledWith(
          expect.objectContaining({ status: 200, appBuild: undefined }),
        );
      });
    });

    describe("ビルド番号が最低バージョンより大きいとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pullSyncChanges(sessionToken, {}, { "x-app-build": "43" });
      });

      test("いつもどおり処理すること", () => {
        expect(response.status).toBe(200);
      });
    });

    describe("ビルド番号のヘッダーが無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pullSyncChanges(sessionToken);
      });

      test("ビルド番号を 0 とみなして締め出すこと", () => {
        expect(response.status).toBe(426);
      });
    });

    describe("ビルド番号が整数として読めないとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pullSyncChanges(sessionToken, {}, { "x-app-build": "43abc" });
      });

      test("ビルド番号を 0 とみなして締め出すこと", () => {
        expect(response.status).toBe(426);
      });
    });

    describe("古いビルドが書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(
          sessionToken,
          { writes: [createWeightRecordWrite()] },
          { "x-app-build": "41" },
        );
      });

      test("締め出すこと", () => {
        expect(response.status).toBe(426);
      });

      test("帳簿に要求も控えも書かないこと", async () => {
        expect({
          requests: await readRows(accountId, "SELECT * FROM sync_request_logs"),
          receipts: await readRows(accountId, "SELECT * FROM sync_write_receipts"),
          changes: await readRows(accountId, "SELECT * FROM record_changes"),
        }).toEqual({ requests: [], receipts: [], changes: [] });
      });
    });

    describe("古いビルドがセッションを持たずに要求したとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await app.request(
          "/v1/sync/changes?afterSequence=0",
          { headers: { "x-app-build": "41" } },
          env,
        );
      });

      test("セッションを確かめる前に締め出すこと", () => {
        expect(response.status).toBe(426);
      });
    });

    describe("古いビルドがサインインしようとしたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await app.request(
          "/v1/sessions",
          {
            method: "POST",
            headers: { "content-type": "application/json", "x-app-build": "41" },
            body: JSON.stringify({}),
          },
          env,
        );
      });

      test("締め出すこと", () => {
        expect(response.status).toBe(426);
      });
    });

    describe("Apple のサーバー間通知がビルド番号のヘッダーなしで届いたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await app.request(
          "/v1/apple-server-notifications",
          {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ payload: "not-a-jws" }),
          },
          env,
        );
      });

      test("締め出しの判定にかけないこと", () => {
        expect(response.status).not.toBe(426);
      });
    });
  });

  describe("最低バージョンを持たない設定で、ビルド番号のヘッダーが無いとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pullSyncChanges(sessionToken);
    });

    test("いつもどおり処理すること", () => {
      expect(response.status).toBe(200);
    });
  });
});
